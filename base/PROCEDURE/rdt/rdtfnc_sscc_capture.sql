SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_SSCC_Capture                                      */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#205447 - RDT SSCC Capture                                    */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-03-08 1.0  James    Created                                          */
/* 2011-09-09 1.1  James    Add print parameter (james01)                    */
/* 2013-04-04 1.2  James    Convert to NVARCHAR (james02)                    */
/* 2016-09-30 1.3  Ung      Performance tuning                               */   
/* 2018-11-14 1.4  Gan      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_SSCC_Capture](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

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
   @cPrinter_Paper      NVARCHAR( 10),

   @cConsigneekey       NVARCHAR( 15),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cOrderKey           NVARCHAR( 10),
   @cOrderLineNumber    NVARCHAR( 5),
   @cLoadKey            NVARCHAR( 10),
   @cNo_Of_SSCC         NVARCHAR( 9),
   @cNo_Of_Ord          NVARCHAR( 9),
   @cNo_Of_SKU          NVARCHAR( 9),
   @cTotal_Qty          NVARCHAR( 13),
   @cOption             NVARCHAR( 1),
   @cSSCC               NVARCHAR( 20),
   @cBatch              NVARCHAR( 20),
   @cSerialNoKey        NVARCHAR( 10),
   @cLot                NVARCHAR( 10),
   @dExpDt              DATETIME,
   @cGTIN               NVARCHAR( 14),
   @cActSKU             NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cDescr              NVARCHAR( 60),
   @c_ErrMsg            NVARCHAR( 20),
   @cGS1_Barcode        NVARCHAR( 55),

   @n_Err               INT,
   @nSKUCnt             INT, 
   @nQty                INT, 
   @nSUM_SR_Qty         INT, 
   @nSUM_PD_Qty         INT,
   @nNo_Of_Scanned_SSCC INT,
   @nNo_Of_Scanned_ORD  INT,
   @nNo_Of_Scanned_SKU  INT,
   @nNo_Of_Scanned_Qty  INT,
   @nNo_Of_ORD          INT,
   @nNo_Of_SKU          INT,
   @nNo_Of_Qty          INT,
   @nSR_Qty             INT, 
   @nPD_Qty             INT, 
   @nActQty             INT,

   @cReportType         NVARCHAR( 10),
   @cPrintJobName       NVARCHAR( 50),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 10),

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

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,
   @cPrinter_Paper   = Printer_Paper,

   @cConsigneekey    = V_ConsigneeKey,
   @cOrderKey        = V_OrderKey,
   @cLoadKey         = V_LoadKey, 

   @cSSCC            = V_String1,

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
IF @nFunc = 873
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 873
   IF @nStep = 1 GOTO Step_1   -- Scn = 2720  LoadKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 2721  LoadKey, Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 2722  LoadKey, SSCC, Qty
   IF @nStep = 4 GOTO Step_4   -- Scn = 2723  LoadKey, SSCC, GS1 Barcode, Lottables
   IF @nStep = 5 GOTO Step_5   -- Scn = 2724  Messages
   IF @nStep = 6 GOTO Step_6   -- Scn = 2725  Messages, Option

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 873)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2720
   SET @nStep = 1

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
   SET @cLoadKey = ''

   -- Init screen
   SET @cOutField01 = ''

   -- Clear log table
   DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
   WHERE AddWho = @cUserName
      AND DESCR = 'RDT SSCC Capture'
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2720
   LoadKey (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01

      -- Validate blank
      IF ISNULL(RTRIM(@cLoadKey), '') = ''
      BEGIN
         SET @nErrNo = 72491
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LoadKey req
         GOTO Step_1_Fail
      END

      -- Check if loadkey exists
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 72492
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv LoadKey
         GOTO Step_1_Fail
      END

      -- Check if finalized
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND FinalizeFlag = 'Y')
      BEGIN
         SET @nErrNo = 72493
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LP Not Finalize
         GOTO Step_1_Fail
      END

      -- Check if transmitlog3 record for tablename 'SSCCLog' created
      IF EXISTS (SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK) WHERE Key1 = @cLoadKey AND Tablename = 'SSCCLog')
      BEGIN
         SET @nErrNo = 72494
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC Finalized
         GOTO Step_1_Fail
      END

      -- Check if loadplan has >1 consignee
--      IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK)
--         WHERE LoadKey = @cLoadKey
--         HAVING COUNT( DISTINCT ConsigneeKey) > 1)
      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
         HAVING COUNT( DISTINCT ConsigneeKey) > 1)
      BEGIN
         SET @nErrNo = 72495
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi-Consignee
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
         HAVING COUNT( DISTINCT StorerKey) > 1)
      BEGIN
         SET @nErrNo = 72524
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi-Consignee
         GOTO Step_1_Fail
      END

      -- Check if every orders have print their pickslip
      IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                 WHERE LoadKey = @cLoadKey
                 AND NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK) WHERE LPD.OrderKey = PH.OrderKey))
      BEGIN
         SET @nErrNo = 72496
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS not Created
         GOTO Step_1_Fail
      END

      -- Check if allocated
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                 JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                 WHERE PD.StorerKey = @cStorerKey
                    AND LPD.LoadKey = @cLoadKey
                 HAVING SUM(PD.Qty) > 0)
      BEGIN
         SET @nErrNo = 72497
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickDet Qty
         GOTO Step_1_Fail
      END

      -- Check if loadkey is not currently locked by other user to do SSCC capture as well
      IF EXISTS (SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK)
                 WHERE LoadKey = @cLoadKey
                    AND AddWho <> @cUserName
                    AND Descr = 'RDT SSCC Capture')
      BEGIN
         SET @nErrNo = 72498
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loadplan Locked
         GOTO Step_1_Fail
      END

      BEGIN TRAN

      INSERT INTO RDT.RDTPICKLOCK
      (WaveKey, LoadKey, OrderKey, OrderLineNumber, PutawayZone, PickZone, PickDetailKey, Descr, Lot, Loc, AddWho, Mobile)
      VALUES
      ('', @cLoadKey, '', '', '', '', '', 'RDT SSCC Capture', '', '', @cUserName, @nMobile)

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72499
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock LP Fail
         GOTO Step_1_Fail
      END

      -- Get no. of SSCC label, Orders, SKU, Qty scanned
      SELECT 
         @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
         @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
         @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
         @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Orders per loadplan
      SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

      -- Get no. of SKU per loadplan
      SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

--      IF @nNo_Of_Scanned_Qty = @nNo_Of_Qty
--      BEGIN
--         ROLLBACK TRAN
--         SET @nErrNo = 72524
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Completed
--         GOTO Step_1_Fail
--      END

      COMMIT TRAN

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
      SET @cOutField03 = @nNo_Of_Scanned_SSCC
      SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
      SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
      SET @cOutField06 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))

      -- initialise all variable
      SET @cOption = ''
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cLoadKey = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2721
   LoadKey (Field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72500
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_2_Fail
      END

      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '2'
      BEGIN
         SET @nErrNo = 72501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_2_Fail
      END

      IF @cOption = '1'
      BEGIN
         IF ISNULL(@cPrinter, '') = ''
         BEGIN
            SET @nErrNo = 72502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO Step_2_Fail
         END

         SET @cReportType = 'SSCCLABEL'
         SET @cPrintJobName = 'PRINT_SSCCLABEL'

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = @cReportType

         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_2_Fail
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_2_Fail
         END

         SET @nErrNo = 0
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cLoadKey, 
            '',                  -- (james01)
            ''                   -- (james01)

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'
            GOTO Step_2_Fail
         END
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Get no. of SSCC label, Orders, SKU, Qty scanned
      SELECT 
         @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
         @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
         @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
         @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Orders per loadplan
      SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

      -- Get no. of SKU per loadplan
      SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
      SET @cOutField03 = @nNo_Of_Scanned_SSCC
      SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
      SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
      SET @cOutField06 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))

      -- initialise all variable
      SET @cSSCC = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- If exist records in serialno table for the Loadplan, go to Screen 6
      IF EXISTS (SELECT 1 FROM dbo.SerialNo SR WITH (NOLOCK)
                 JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
                 WHERE LPD.LoadKey = @cLoadKey
                    AND SR.StorerKey = @cStorerKey)
      BEGIN
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4

         --prepare next screen variable
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @cTotal_Qty
         SET @cOutField03 = ''

         -- initialise all variable
         SET @cOption = ''
      END
      ELSE
      BEGIN
         DELETE FROM RDT.RDTPICKLOCK
         WHERE  LoadKey = @cLoadKey
            AND DESCR = 'RDT SSCC Capture'
            AND AddWho = @cUserName

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         -- initialise all variable
         SET @cLoadKey = ''

         -- Init screen
         SET @cOutField01 = ''
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField02 = ''
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2722
   LoadKey (Field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Validate blank
      IF ISNULL(@cInField02, '') = ''
      BEGIN
         SET @nErrNo = 72506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC req
         GOTO Step_3_Fail
      END

      -- If ScannedBarcode Length <> 20 Or First 2 NVARCHAR (AI code) <> '00' Or is not all Numeric Digit [0-9]
      IF LEN(@cInField02) <> 20 OR SUBSTRING(@cInField02, 1, 2) <> '00' OR ISNUMERIC(@cInField02) <> 1
      BEGIN
         SET @nErrNo = 72507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
         GOTO Step_3_Fail
      END

      -- If Check Digit <> Substring(ScannedBarcode,20,1)
      IF dbo.fnc_CalcCheckDigit_M10(SUBSTRING(@cInField02, 3, 17), 0) <> SUBSTRING(@cInField02, 20, 1)
      BEGIN
         SET @nErrNo = 72508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CheckDigit Err
         GOTO Step_3_Fail
      END

      SET @cSSCC = SUBSTRING(@cInField02, 3, 18)

      IF EXISTS (SELECT 1 FROM dbo.SerialNo SR WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
      JOIN dbo.Storer STR WITH (NOLOCK) ON SR.StorerKey=STR.StorerKey
      WHERE LPD.LoadKey <> @cLoadKey
         AND STR.LabelPrice IN (SELECT LabelPrice FROM dbo.Storer WHERE StorerKey = @cStorerKey)
         AND SR.SerialNo = SUBSTRING(@cInField02, 3, 18)
      HAVING DateAdd(Year, 1, MAX(SR.AddDate)) >= GetDate())
      BEGIN
         SET @nErrNo = 72509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC Reuse Err
         GOTO Step_3_Fail
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Get no. of Qty scanned
      SELECT @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = @cSSCC
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Get no. of SSCC label, Orders, SKU, Qty scanned
      SELECT 
         @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
         @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
         @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
         @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Orders per loadplan
      SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

      -- Get no. of SKU per loadplan
      SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
      SET @cOutField03 = @nNo_Of_Scanned_SSCC
      SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
      SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
      SET @cOutField06 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))

      -- initialise all variable
      SET @cOption = ''
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField02 = ''
      SET @cSSCC = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2723
   LoadKey (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cGS1_Barcode = @cInField03

      -- Validate blank
      IF ISNULL(@cInField03, '') = ''
      BEGIN
         -- Get no. of Qty scanned
         SELECT @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
         FROM dbo.SerialNo SR WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
         WHERE O.StorerKey = @cStorerKey
            AND LPD.LoadKey = @cLoadKey

         -- Get no. of Qty per loadplan
         SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

         -- If scan complete, go to Screen 5
         IF @nNo_Of_Scanned_Qty = @nNo_Of_Qty
         BEGIN
            -- Get no. of SSCC label, Orders, SKU, Qty scanned
            SELECT 
               @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
               @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
               @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
               @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
            FROM dbo.SerialNo SR WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
            WHERE O.StorerKey = @cStorerKey
               AND LPD.LoadKey = @cLoadKey

            -- Get no. of Orders per loadplan
            SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
            FROM dbo.LoadPlanDetail WITH (NOLOCK) 
            WHERE LoadKey = @cLoadKey

            -- Get no. of SKU per loadplan
            SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey

            -- Get no. of Qty per loadplan
            SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey

            --prepare next screen variable
            SET @cOutField01 = @cLoadKey
            SET @cOutField02 = @nNo_Of_Scanned_SSCC
            SET @cOutField03 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
            SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
            SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))
            SET @cOutField06 = ''
            SET @cOption = ''

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 72510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Barcode req
            GOTO Step_4_Fail
         END
      END

      -- GS1 decoding procedure
      EXEC dbo.ispGS1_Barcode_Decode 
         @cGS1_Barcode = @cGS1_Barcode, 
         @cGTIN        = @cGTIN    OUTPUT, 
         @dExpDt       = @dExpDt   OUTPUT, 
         @cBatch       = @cBatch   OUTPUT, 
         @nQty         = @nQty     OUTPUT 

      IF @dExpDt = 0 OR RDT.RDTFormatDate(@dExpDt) = '01/01/1900' 
         SET @dExpDt = NULL

      -- Truncate the time portion
      IF @dExpDt IS NOT NULL
         SET @dExpDt = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dExpDt, 120), 120)

      -- Use the GTIN-14 code together with Storerkey to search the actual Sku code
      SET @cActSKU = @cGTIN

      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cActSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF @nSKUCnt = 0
      BEGIN
         -- If not found and GTIN-14 like '0%', then search Substring (GTIN-14, 2, 13) again
         IF @cGTIN LIKE '0%'
         BEGIN
            SET @cActSKU = SUBSTRING(@cActSKU, 2, 13)

            EXEC [RDT].[rdt_GETSKUCNT]
               @cStorerKey  = @cStorerKey,
               @cSKU        = @cActSKU,
               @nSKUCnt     = @nSKUCnt       OUTPUT,
               @bSuccess    = @b_Success     OUTPUT,
               @nErr        = @n_Err         OUTPUT,
               @cErrMsg     = @c_ErrMsg      OUTPUT

            IF @nSKUCnt = 0
            BEGIN
               -- If not found and GTIN-14 like '00%', then search Substring (GTIN-14, 3, 12)
               IF @cGTIN LIKE '00%' 
               BEGIN
                  SET @cActSKU = @cGTIN
                  SET @cActSKU = SUBSTRING(LTRIM(RTRIM(@cActSKU)), 3, 12)

                  EXEC [RDT].[rdt_GETSKUCNT]
                     @cStorerKey  = @cStorerKey,
                     @cSKU        = @cActSKU,
                     @nSKUCnt     = @nSKUCnt       OUTPUT,
                     @bSuccess    = @b_Success     OUTPUT,
                     @nErr        = @n_Err         OUTPUT,
                     @cErrMsg     = @c_ErrMsg      OUTPUT

                  IF @nSKUCnt = 0
                  BEGIN
                     SET @nErrNo = 72511
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Sku 
                     GOTO Step_4_Fail
                  END
               END   -- IF @cGTIN LIKE '00%'
               ELSE
               BEGIN
                  SET @nErrNo = 72511
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Sku 
                  GOTO Step_4_Fail
               END
            END
         END   -- IF @cGTIN LIKE '0%'
      END   -- IF @nSKUCnt = 0

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cActSKU       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      SET @cSKU = @cActSKU

      IF NOT EXISTS (SELECT 1 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      JOIN LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = ISNULL(@cSKU, '')
         AND LA.Lottable02 = ISNULL(@cBatch, '')
         AND IsNULL( Lottable04, 0) = IsNULL( @dExpDt, 0))

      -- If Sku + Batch# + Expiry Date not found in the Loadplan
      BEGIN
         SET @nErrNo = 72512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot/ExpDt Err 
         GOTO Step_4_Fail
      END

      -- If Scanned Qty <= 0
      IF ISNULL(@nQty, 0) <= 0
      BEGIN
         SET @nErrNo = 72513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty 
         GOTO Step_4_Fail
      END

      -- If SUM(Serialno.Qty) + Scanned Qty > SUM(Pickdetail.Qty) of that Sku+Lot
      SELECT @nSUM_SR_Qty = ISNULL( SUM( SR.Qty), 0) 
      FROM dbo.SerialNo SR WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON SR.LOTNo = LA.LOT
      WHERE LPD.LoadKey = @cLoadKey
         AND SR.StorerKey = @cStorerKey
         AND SR.SKU = ISNULL(@cSKU, '')
         AND LA.Lottable02 = ISNULL(@cBatch, '')
         AND IsNULL( Lottable04, 0) = IsNULL( @dExpDt, 0)

      SELECT @nSUM_PD_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      JOIN LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = ISNULL(@cSKU, '')
         AND LA.Lottable02 = ISNULL(@cBatch, '')
         AND IsNULL( Lottable04, 0) = IsNULL( @dExpDt, 0)

      IF (@nSUM_SR_Qty + @nQty) > @nSUM_PD_Qty
      BEGIN
         SET @nErrNo = 72514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Overflow 
         GOTO Step_4_Fail
      END

      SET @nActQty = @nQty
      SET @cOrderKey = ''
      SET @cOrderLineNumber = ''

      BEGIN TRAN
-- When Insert or Update SerialNo record, please break by Orderkey, OrderLineNumber, StorerKey, Sku, SerialNo, LotNo.
--It is because when extracting SSCC for ASN EDI interface, we need to join SerailNo table to OrderDetail for retriving HA PO# and PO Line#. 

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT PD.OrderKey, PD.OrderLineNumber, PD.LOT, SUM(PD.Qty)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      JOIN LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = ISNULL(@cSKU, '')
         AND LA.Lottable02 = ISNULL(@cBatch, '')
         AND IsNULL( Lottable04, 0) = IsNULL( @dExpDt, 0)
      GROUP BY PD.OrderKey, PD.OrderLineNumber, PD.LOT
      ORDER BY PD.OrderKey, PD.OrderLineNumber, PD.LOT
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cOrderLineNumber, @cLOT, @nPD_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @nSR_Qty = ISNULL( SUM(SR.Qty), 0)
         FROM dbo.SerialNo SR WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND SR.StorerKey = @cStorerKey
            AND SR.OrderKey = @cOrderKey
            AND SR.OrderLineNumber = @cOrderLineNumber
            AND SR.SKU = @cSKU
            AND SR.LotNo = @cLOT

         IF @nQty + @nSR_Qty > @nPD_Qty
         BEGIN
            SET @nSR_Qty = @nPD_Qty - @nSR_Qty
            SET @nQty = @nQty - @nSR_Qty
         END
         ELSE
         BEGIN
            SET @nSR_Qty = @nQty
            SET @nQty = 0
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.SerialNo SR WITH (NOLOCK)
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
                        WHERE SR.StorerKey = @cStorerKey
                           AND LPD.LoadKey = @cLoadKey
                           AND SR.SerialNo = @cSSCC
                           AND SR.OrderKey = @cOrderKey
                           AND SR.OrderLineNumber = @cOrderLineNumber
                           AND SR.SKU = @cSKU
                           AND SR.LotNo = @cLOT)
         BEGIN
            -- Start insert ADCode
            EXECUTE dbo.nspg_GetKey
               'SerialNo',
               10 ,
               @cSerialNoKey      OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72515
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get SRKey Fail'
               GOTO Step_4_Fail
            END

            INSERT INTO dbo.SerialNo
            (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty, Status, LotNo, AddWho, AddDate)
            VALUES
            (@cSerialNoKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @cSSCC, @nSR_Qty, '0', @cLOT, 'rdt.' + @cUserName, GETDATE())

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72516
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS SRDTL Fail'
               GOTO Step_4_Fail
            END
            ELSE
            BEGIN
              EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '20', 
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = '',
                 @cID           = '',
                 @cSKU          = @cSKU,
                 @cUOM          = '',
                 @nQTY          = @nSR_Qty,
                 @cLot          = @cLOT,
                 @cLoadKey      = @cLoadKey,
                 --@cRefNo1       = @cLoadKey,
                 @cOrderKey     = @cOrderKey,
                 --@cRefNo2       = @cOrderKey,
                 @cSSCC         = @cSSCC,
                 --@cRefNo3       = @cSSCC,
                 @cSerialNoKey  = @cSerialNoKey,
                 --@cRefNo4       = @cSerialNoKey,
                 @nStep         = @nStep
            END
         END
         ELSE
         BEGIN
            UPDATE SR WITH (ROWLOCK) SET 
               Qty = ISNULL(Qty, 0) + @nSR_Qty 
            FROM dbo.SerialNo SR 
            JOIN dbo.LoadPlanDetail LPD ON SR.OrderKey = LPD.OrderKey
            WHERE SR.StorerKey = @cStorerKey
               AND LPD.LoadKey = @cLoadKey
               AND SR.SerialNo = @cSSCC
               AND SR.OrderKey = @cOrderKey
               AND SR.OrderLineNumber = @cOrderLineNumber
               AND SR.SKU = @cSKU
               AND SR.LotNo = @cLOT


            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72517
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD SRDTL Fail'
               GOTO Step_4_Fail
            END
            ELSE
            BEGIN
              EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '20', 
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = '',
                 @cID           = '',
                 @cSKU          = @cSKU,
                 @cUOM          = '',
                 @nQTY          = @nSR_Qty,
                 @cLot          = @cLOT,
                 @cLoadKey      = @cLoadKey,
                 --@cRefNo1       = @cLoadKey,
                 @cOrderKey     = @cOrderKey,
                 --@cRefNo2       = @cOrderKey,
                 @cSSCC         = @cSSCC,
                 --@cRefNo3       = @cSSCC,
                 @cSerialNoKey  = @cSerialNoKey,
                 --@cRefNo4       = @cSerialNoKey
                 @nStep         = @nStep
            END
         END

         IF @nQty = 0 
            BREAK
         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cOrderLineNumber, @cLOT, @nPD_Qty
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      COMMIT TRAN

      -- Get no. of Qty scanned
      SELECT @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      -- If scan complete, go to Screen 5
      IF @nNo_Of_Scanned_Qty = @nNo_Of_Qty
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         -- Get no. of SSCC label, Orders, SKU, Qty scanned
         SELECT 
            @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
            @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
            @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
            @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
         FROM dbo.SerialNo SR WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
         WHERE O.StorerKey = @cStorerKey
            AND LPD.LoadKey = @cLoadKey

         -- Get no. of Orders per loadplan
         SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
         FROM dbo.LoadPlanDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey

         -- Get no. of SKU per loadplan
         SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

         -- Get no. of Qty per loadplan
         SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

            --prepare next screen variable
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @nNo_Of_Scanned_SSCC
         SET @cOutField03 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
         SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
         SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))
         SET @cOutField06 = ''
         SET @cOption = ''
      END
      ELSE
      BEGIN      
         SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

         -- Get no. of Qty scanned
         SELECT @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
         FROM dbo.SerialNo SR WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
         WHERE O.StorerKey = @cStorerKey
            AND LPD.LoadKey = @cLoadKey

         -- Get no. of Qty per loadplan
         SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @cSSCC
         SET @cOutField03 = ''
         SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING(@cDescr, 1, 20)
         SET @cOutField06 = SUBSTRING(@cDescr, 21, 20)
         SET @cOutField07 = @cBatch
         SET @cOutField08 = CONVERT(NVARCHAR( 10), @dExpDt, 103)
         SET @cOutField09 = @nActQty
         SET @cOutField10 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Get no. of SSCC label, Orders, SKU, Qty scanned
      SELECT 
         @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
         @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
         @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
         @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
      FROM dbo.SerialNo SR WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      WHERE O.StorerKey = @cStorerKey
         AND LPD.LoadKey = @cLoadKey

      -- Get no. of Orders per loadplan
      SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
      FROM dbo.LoadPlanDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

      -- Get no. of SKU per loadplan
      SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      -- Get no. of Qty per loadplan
      SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
      SET @cOutField03 = @nNo_Of_Scanned_SSCC
      SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
      SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
      SET @cOutField06 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))

      -- initialise all variable
      SET @cSSCC = ''
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField03 = ''
      SET @cGS1_Barcode = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2724
   LoadKey (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField06

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_5_Fail
      END

      IF ISNULL(@cOption, '') NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 72519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      -- Generate Transmitlog3 (tablename='SSCCLog') for the LoadKey
      IF @cOption = 1
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'SSCCLOG', @cLoadKey, '', @cStorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 72520
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
            GOTO Step_5_Fail
         END

         -- Release Loadplan/Orders lock
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
         WHERE AddWho = @cUserName
            AND DESCR = 'RDT SSCC Capture'
            AND LoadKey = @cLoadKey

         --Go back to Screen 1
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         -- initialise all variable
         SET @cLoadKey = ''

         -- Init screen
         SET @cOutField01 = ''
      END

      IF @cOption = 2
      BEGIN
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         --prepare next screen variable
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = @cSSCC
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      --prepare next screen variable
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = @cSSCC
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField06 = ''
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2725
   LoadKey (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72521
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_6_Fail
      END

      IF ISNULL(@cOption, '') NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 72522
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = 1
      BEGIN
         -- Release Loadplan/Orders lock
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
         WHERE AddWho = @cUserName
            AND DESCR = 'RDT SSCC Capture'
            AND LoadKey = @cLoadKey

         --Go back to Screen 1
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5

         -- initialise all variable
         SET @cLoadKey = ''

         -- Init screen
         SET @cOutField01 = ''
      END

      IF @cOption = 2
      BEGIN
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         -- Get no. of SSCC label, Orders, SKU, Qty scanned
         SELECT 
            @nNo_Of_Scanned_SSCC = COUNT( DISTINCT SR.SerialNo), 
            @nNo_Of_Scanned_ORD = COUNT( DISTINCT SR.OrderKey), 
            @nNo_Of_Scanned_SKU = COUNT( DISTINCT SR.SKU), 
            @nNo_Of_Scanned_Qty = ISNULL( SUM(SR.QTY), 0)  
         FROM dbo.SerialNo SR WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON SR.OrderKey = O.OrderKey
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
         WHERE O.StorerKey = @cStorerKey
            AND LPD.LoadKey = @cLoadKey

         -- Get no. of Orders per loadplan
         SELECT @nNo_Of_ORD = COUNT( DISTINCT OrderKey) 
         FROM dbo.LoadPlanDetail WITH (NOLOCK) 
         WHERE LoadKey = @cLoadKey

         -- Get no. of SKU per loadplan
         SELECT @nNo_Of_SKU = COUNT( DISTINCT PD.SKU) 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

         -- Get no. of Qty per loadplan
         SELECT @nNo_Of_Qty = ISNULL( SUM(PD.Qty), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey

         --prepare next screen variable
         SET @cOutField01 = @cLoadKey
         SET @cOutField02 = ''
         SET @cOutField03 = @nNo_Of_Scanned_SSCC
         SET @cOutField04 = RTRIM(CAST( @nNo_Of_Scanned_ORD AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_ORD AS NVARCHAR(4)))
         SET @cOutField05 = RTRIM(CAST( @nNo_Of_Scanned_SKU AS NVARCHAR(4))) + '/' + LTRIM(CAST( @nNo_Of_SKU AS NVARCHAR(4)))
         SET @cOutField06 = RTRIM(CAST( @nNo_Of_Scanned_Qty AS NVARCHAR(6))) + '/' + LTRIM(CAST( @nNo_Of_Qty AS NVARCHAR(6)))

         -- initialise all variable
         SET @cOption = ''
      END

      IF @cOption = 3
      BEGIN
         -- Delete all scanned SSCC records for this Loadplan 
         BEGIN TRAN

         DELETE SR 
         FROM dbo.SerialNo SR WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SR.OrderKey = LPD.OrderKey
         WHERE SR.StorerKey = @cStorerKey
            AND LPD.LoadKey = @cLoadKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 72523
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL SR Fail
            GOTO Step_6_Fail
         END

         COMMIT TRAN

         -- Release Loadplan/Orders lock
         DELETE FROM RDT.RDTPickLock WITH (ROWLOCK)
         WHERE AddWho = @cUserName
            AND DESCR = 'RDT SSCC Capture'
            AND LoadKey = @cLoadKey

         --Go back to Screen 1
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5

         -- initialise all variable
         SET @cLoadKey = ''

         -- Init screen
         SET @cOutField01 = ''
      END
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cOutField03 = ''
      SET @cOption = ''
   END
END
GOTO Quit

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

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,
  
      V_ConsigneeKey = @cConsigneekey,  
      V_OrderKey     = @cOrderKey,  
      V_LoadKey      = @cLoadKey,  

      V_String1      = @cSSCC,  


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
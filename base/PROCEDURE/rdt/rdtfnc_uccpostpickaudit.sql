SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_UCCPostPickAudit                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS93812 - Move By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-01-02 1.0  Ung      SOS265338. Created                          */
/* 2014-04-30 1.1  Ung      SOS309811. Support XDock                    */
/* 2016-09-30 1.2  Ung      Performance tuning                          */  
/* 2017-03-08 1.3  James    WMS1219-Add extended confirm sp (james01)   */  
/* 2017-09-27 1.4  TLTING   Missing NOLOCK                              */ 
/* 2018-10-03 1.5  TungGH   Performance                                 */ 
/* 2021-09-22 1.6  James    WMS-17972 Migrate to rdt_print (james02)    */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCPostPickAudit] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cDataWindow NVARCHAR( 50), 
   @cTargetDB   NVARCHAR( 20), 
   @cOption     NVARCHAR( 1)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR( 18),
   @cLabelPrinter   NVARCHAR( 10),
   @cPaperPrinter   NVARCHAR( 10),

   @cPrintDispatchLabel NVARCHAR( 1),
   @cPrintPackList      NVARCHAR( 1),
   @cExtendedUpdateSP   NVARCHAR( 20), 
   @cExtendedConfirmSP  NVARCHAR( 20), 
   @cSQL                NVARCHAR( 2000), 
   @cSQLParam           NVARCHAR( 2000), 
   @tDispatchTicket     VariableTable,
   @tPackList           VariableTable,
   
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
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName, 
   @cLabelPrinter = Printer,
   @cPaperPrinter = Printer_Paper,

   @cPrintDispatchLabel = V_String1,
   @cPrintPackList      = V_String2,
   @cExtendedUpdateSP   = V_String3,
   @cExtendedConfirmSP  = V_String4,

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

-- Redirect to respective screen
IF @nFunc = 580
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 580
   IF @nStep = 1 GOTO Step_1   -- Scn = 2980. LabelNo
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3370
   SET @nStep = 1

   -- Init var

   -- Get StorerConfig
   SET @cPrintDispatchLabel = rdt.RDTGetConfig( 580, 'DispatchLabel', @cStorerKey)
   SET @cPrintPackList = rdt.RDTGetConfig( 580, 'PackingList', @cStorerKey)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( 580, 'ExtendedUpdateSP', @cStorerKey)

   -- (james01)
   SET @cExtendedConfirmSP = rdt.RDTGetConfig( @nFunc, 'ExtendedConfirmSP', @cStorerKey)
   IF @cExtendedConfirmSP = '0'
      SET @cExtendedConfirmSP = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cOutField01 = ''  -- LabelNo
   SET @cOutField02 = ''  -- Last LabelNo
   SET @cOutField03 = @cPrintDispatchLabel
   SET @cOutField04 = @cPrintPackList

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


/********************************************************************************
Step 1. Screen = 2980
   UCC   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUCC NVARCHAR( 20)

      -- Screen mapping
      SET @cUCC = @cInField01

      -- Retain key-in value
      SET @cOutField01 = @cUCC

      -- Validate blank
      IF @cUCC = ''
      BEGIN
         SET @nErrNo = 78651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      DECLARE @cPickSlipNo NVARCHAR(10)
      DECLARE @cPickDetailKey NVARCHAR(10)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cUOM NVARCHAR(10)
      DECLARE @cType NVARCHAR(2)
      DECLARE @cOrderKey NVARCHAR(10)
      
      SET @cPickDetailKey = ''
      SET @cPickSlipNo = ''
      SET @cType = ''

      -- Check for normal UCC
      SELECT TOP 1 
         @cPickSlipNo = PickSlipNo, 
         @cPickDetailKey = PickDetailKey, 
         @cLOC = LOC, 
         @cUOM = UOM
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND DropID = @cUCC
         AND Status IN ('0', '3') -- 0=Replenish, 3=Pick in progress
      ORDER BY Status DESC        -- Take 3-Pick in progress 1st. Due to launch order full case swap UCC, original PickDetail.DropID not overwrite

      -- Check for XDock UCC
      IF @@ROWCOUNT = 0
      BEGIN
         DECLARE @cLOT NVARCHAR(10)
         SELECT TOP 1 @cLOT = LOT FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC
         SELECT TOP 1 @cOrderKey = OrderKey FROM PickDetail WITH (NOLOCK) WHERE LOT = @cLOT
         SELECT @cType = 'XD' FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND RIGHT( Type, 2) = '-X' -- XDock order
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      END

      -- XDock UCC
      IF @cType = 'XD'
      BEGIN
         -- Check double scan
         IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            SET @nErrNo = 78667
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            GOTO Step_1_Fail
         END

         EXEC rdt.rdt_UCCPostPickAudit_ConfirmXDock @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, 
            @cUCC, 
            @nErrNo  OUTPUT, 
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      -- Normal UCC
      IF @cType = ''
      BEGIN
         -- Check if valid ID
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 78652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
            GOTO Step_1_Fail
         END
         
         -- Check full case
         IF @cUOM <> '2'
         BEGIN
            SET @nErrNo = 78666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not full case
            GOTO Step_1_Fail
         END
   
         -- Get order info
         DECLARE @cSOStatus NVARCHAR(10)
         DECLARE @cPDStatus NVARCHAR(10)
         SELECT @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey
         SELECT @cSOStatus = SOStatus FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
         SELECT @cPDStatus = MAX( Status) FROM dbo.PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   
         -- Order cancel and not start picking, not print dispatch label and packing list
         IF @cSOStatus = 'CANC' AND @cPDStatus = '0'
         BEGIN
            SET @nErrNo = 78653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order cancel
            GOTO Step_1_Fail
         END
         
         -- Check double scan
         IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            SET @nErrNo = 78654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
            GOTO Step_1_Fail
         END

         -- Extended update
         IF @cExtendedConfirmSP <> ''
         BEGIN
            SET @nErrNo = 0
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cExtendedConfirmSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedConfirmSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cFacility, @cStorerKey, @cLOC, @cPickDetailKey, @cUCC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cLOC            NVARCHAR( 10), ' +
                  '@cPickDetailKey  NVARCHAR( 10), ' + 
                  '@cUCC            NVARCHAR( 20), ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cFacility, @cStorerKey, @cLOC, @cPickDetailKey, @cUCC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_1_Fail
               ELSE  -- No need print label & no need exec ispJungheinrich command
               BEGIN
                  -- Remain in current screen
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cUCC --LastID                  
               
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            -- Update Orders, PickDetail, UCC
            -- Insert PackHeader, PackDetail, DropID
            EXEC rdt.rdt_UCCPostPickAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, 
               @cLOC, 
               @cPickDetailKey, 
               @cUCC, 
               @nErrNo  OUTPUT, 
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail

         END
      END
               
      -- Print dispatch label
      IF @cPrintDispatchLabel = '1'
      BEGIN
         /*
         -- Check label printer blank
         IF @cLabelPrinter = ''
         BEGIN
            SET @nErrNo = 78655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO Quit
         END

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND ReportType = 'DESPATCHTK'
      
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 78656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_1_Fail
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 78657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_1_Fail
         END
         */
         -- Get CartonNo
         DECLARE @nCartonNo INT
         SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cUCC

         -- (james02)
         -- Print dispatch label  
         INSERT INTO @tDispatchTicket (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
         INSERT INTO @tDispatchTicket (Variable, Value) VALUES ( '@nCartonNo',   @nCartonNo)
         INSERT INTO @tDispatchTicket (Variable, Value) VALUES ( '@nCartonNo',   @nCartonNo)
           
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, '', @cStorerKey, @cLabelPrinter, '',   
            'DESPATCHTK',     -- Report type  
            @tDispatchTicket, -- Report params  
            'PRINT_DESPATCHTK',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT
         
         /*               
         -- Insert print job
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'DESPATCHTK',       -- ReportType
            'PRINT_DESPATCHTK', -- PrintJobName
            @cDataWindow,
            @cLabelPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @cPickSlipNo, 
            @nCartonNo,  -- Start CartonNo
            @nCartonNo,  -- End CartonNo
            '',          -- Start LabelNo
            ''           -- End LabelNo
         */
         
         -- Update DropID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            -- Insert DropID
            INSERT INTO dbo.DropID (DropID, LabelPrinted, Status) VALUES (@cUCC, '1', '9')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 78658
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
               GOTO Step_1_Fail
            END
         END
         ELSE
         BEGIN
            -- Update DropID
            UPDATE dbo.DropID WITH (ROWLOCK)
            SET LabelPrinted = '1'
            WHERE DropID = @cUCC
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 78659
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
               GOTO Step_1_Fail
            END
         END
      END

      -- Print pack list
      IF @cPrintPackList = '1'
      BEGIN
         /*
         -- Check paper printer blank
         IF @cPaperPrinter = ''
         BEGIN
            SET @nErrNo = 78660
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
            EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label
            GOTO Quit
         END

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND ReportType = 'PACKLIST'
      
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 78661
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_1_Fail
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 78662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_1_Fail
         END
         */
         
         -- Insert DropID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            -- Insert DropID
            INSERT INTO dbo.DropID (DropID, Status) VALUES (@cUCC, '9')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 78663
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
               GOTO Step_1_Fail
            END
         END
   
         DECLARE @cLastCarton NVARCHAR( 1)

         -- Check last carton, for XDock UCC
         IF @cType = 'XD'
         BEGIN
            /*
            Last carton logic:
            1. If not fully pack (PickDetail.Status = 4), definitely not last carton
            2. If pick QTY tally pack QTY
            */
            -- 1. Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status IN ('4'))
               SET @cLastCarton = 'N' 
            ELSE
            BEGIN
               DECLARE @nPickQTY INT
               DECLARE @nPackQTY INT
               SELECT @nPickQTY = ISNULL( SUM( QTY), 0) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status <> '4'
               SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
         
               -- 2. Pick tally Pack QTY
               IF @nPickQTY <> @nPackQTY
                  SET @cLastCarton = 'N' 
               ELSE
                  SET @cLastCarton = 'Y' 
            END
         END

         -- Check last carton, for Normal UCC
         IF @cType = ''
         BEGIN
            /*
            Last carton logic:
            1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton
            2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton
            */
            -- 1. Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status IN ('0', '4'))
               SET @cLastCarton = 'N' 
            ELSE
               -- 2. Check manifest printed
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.PackDetail PD WITH (NOLOCK) 
                     LEFT JOIN dbo.DropID WITH (NOLOCK) ON (PD.DropID = DropID.DropID)
                  WHERE PD.PickSlipNo = @cPickSlipNo 
                     AND DropID.DropID IS NULL)
                  SET @cLastCarton = 'N' 
               ELSE
                  SET @cLastCarton = 'Y' 
         END

         -- Insert print job
         IF @cLastCarton = 'Y'
         BEGIN
            -- (james02)
            -- Print packing list  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
           
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, '', @cStorerKey, '', @cPaperPrinter,   
               'PACKLIST',       -- Report type  
               @tPackList,       -- Report params  
               'PRINT_PACKLIST',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT

            /*
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               'PACKLIST',       -- ReportType
               'PRINT_PACKLIST', -- PrintJobName
               @cDataWindow,
               @cPaperPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT, 
               @cPickSlipNo
            */
            
            -- Prompt message
            SET @nErrNo = 78664
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackLstPrinted
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''

            -- Update DropID
            UPDATE dbo.DropID WITH (ROWLOCK)
            SET  ManifestPrinted = '1'
            WHERE DropID = @cUCC
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 78665
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
               GOTO Step_1_Fail
            END
         END
      END
      
      -- Send WCS message
      EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cUCC, @cOrderKey

      -- Remain in current screen
      SET @cOutField01 = ''
      SET @cOutField02 = @cUCC --LastID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- Logging
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
      SET @cOutField01 = '' -- Clean up for menu option

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

   Step_1_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField01 = '' -- UCC
      EXEC rdt.rdtSetFocusField @nMobile, 1 --UCC
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,-- (Vicky06)
      Printer    = @cLabelPrinter ,
      Printer_Paper = @cPaperPrinter ,

      V_String1 = @cPrintDispatchLabel,
      V_String2 = @cPrintPackList,
      V_String3 = @cExtendedUpdateSP,
      V_String4 = @cExtendedConfirmSP,

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
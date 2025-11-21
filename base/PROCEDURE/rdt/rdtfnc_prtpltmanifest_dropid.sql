SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PrtPltManifest_DropID                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Report/Label printing by DropID (SOS#133303)            */
/*          SOS93811 - Pick By Drop ID                                  */
/*          SOS93812 - Pick By Drop ID                                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2009-04-03 1.0  Vicky    Created                                     */
/* 2009-07-13 1.1  Vicky    SOS#141643 - To allow Printing for Pickslip */
/*                          that has not being scan in (Vicky01)        */
/* 2009-07-31 1.2  Vicky    Have to cater for XD Orders, which the      */
/*                          PickHeader.ExternOrderkey <> Loadkey        */
/*                          (Vicky02)                                   */
/* 2009-08-27 1.3	 GTGOH	 Allow Printing without LoadnPlan				*/
/*									 -SOS#145273											*/
/* 2010-05-18 1.4  ChewKP	 Additional Option for Dispatch Label			*/
/*									 SOS#172042	(ChewKP01)								*/
/*            1.5  TLTing                                               */
/* 2011-03-14 1.6  Ung      Add printer field. Support DropID not on    */
/*                          PickDetail, but only on PackDetail          */
/* 2012-04-16 1.7  Ung      Expand DropID to 20 chars                   */
/* 2013-02-19 1.8  GTGOH    SOS#267833 - Add option for Carton Manifest */
/*                          Label (GOH01)                               */
/* 2013-06-28 1.9  James    SOS282610 - Add customizable DropID check   */
/*                          stored proc (james01)                       */
/* 2016-09-30 2.0  Ung      Performance tuning                          */  
/* 2018-05-07 2.1  James    WMS4941-Change to use rdt_Print             */                  
/* 2020-02-18 2.2  James    Add new label printing for option 4(james02)*/                  
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PrtPltManifest_DropID] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,


   @cStorer         NVARCHAR( 15),
   @cPrinter        NVARCHAR( 10),
   @cUserName       NVARCHAR( 18),
   @cFacility       NVARCHAR( 5),
   @cDataWindow     NVARCHAR( 50), 
   @cTargetDB       NVARCHAR( 10), 
   @cDropID         NVARCHAR( 20),
   @cOrderkey       NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),
   @cLoadkey        NVARCHAR( 10),

   @cNo_PSNO        NVARCHAR(  1), -- (Vicky02)
   @cExternPOKey    NVARCHAR( 20), -- (Vicky02)
   @cNoLoadPlan     NVARCHAR(  1), -- SOS#145273
   @cTempPrinter    NVARCHAR( 10),
   @cDropIDChkSP    NVARCHAR( 20),  -- (james01)
   @cParam1         NVARCHAR( 20),  -- (james01)
   @cParam2         NVARCHAR( 20),  -- (james01)
   @cParam3         NVARCHAR( 20),  -- (james01)
   @cParam4         NVARCHAR( 20),  -- (james01)
   @cParam5         NVARCHAR( 20),  -- (james01)
   @cSQL            NVARCHAR(1000), -- (james01)     
   @cSQLParam       NVARCHAR(1000), -- (james01)  
   @cReportType     NVARCHAR( 20),  -- (james01)
   @cInterCOLBL     NVARCHAR( 10),  -- (james02)
   @cConsigneeKey   NVARCHAR( 15),  -- (james02)
   
   
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

   @cStorer     = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer, 

   @cOrderKey    = V_String1,
   @cDropID      = V_String2,
   @cPickSlipNo  = V_String3,
   @cLoadkey     = V_String4,
   @cTempPrinter = V_String5,
   @cInterCOLBL  = V_String6,
   @cConsigneeKey= V_String7,

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

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 972
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 972
   IF @nStep = 1 GOTO Step_1   -- Scn = 2020. PSno
   IF @nStep = 2 GOTO Step_2   -- Scn = 2021. Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 515)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 2020
   SET @nStep = 1

   -- Show printer
   SET @cTempPrinter = @cPrinter
   IF @cTempPrinter = '' OR @cTempPrinter IS NULL
      EXEC rdt.rdtSetFocusField @nMobile, 1
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cTempPrinter
      SET @cOutField02 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   SET @cInterCOLBL = rdt.rdtGetConfig( @nFunc, 'INTERCOLBL', @cStorer)
   
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 2020
   DROP ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTempPrinter = @cInField01
      SET @cDropID = @cInField02
      
      -- Validate blank printer
      IF @cTempPrinter = '' OR @cTempPrinter IS NULL 
      BEGIN
         SET @nErrNo = 66750
         SET @cErrMsg = rdt.rdtgetmessage( 66750, @cLangCode,'DSP') -- NoLoginPrinter
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = @cTempPrinter
         GOTO Step_1_Fail
      END
      
      -- Validate printer
      IF NOT EXISTS( SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM( @cTempPrinter))  
      BEGIN
         SET @nErrNo = 66751
         SET @cErrMsg = rdt.rdtgetmessage( 66751, @cLangCode,'DSP') -- InvalidPrinter
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = @cTempPrinter
         GOTO Step_1_Fail
      END
      SET @cOutField01 = @cTempPrinter
             
      -- Validate blank DropID
      IF @cDropID = '' OR @cDropID IS NULL
      BEGIN
         SET @nErrNo = 66740
         SET @cErrMsg = rdt.rdtgetmessage( 66740, @cLangCode,'DSP') -- DROPID req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)
      DECLARE @nCnt           INT
      DECLARE @dScanInDate    DATETIME
      DECLARE @dScanOutDate   DATETIME

      -- Get OrderKey from PickDetail
      SET @cOrderKey = ''
      SELECT TOP 1
         @cOrderKey = OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorer 
      AND   DropID = @cDropID

      IF @cOrderKey = '' OR @cOrderKey IS NULL
         -- Get OrderKey from PackDetail
         SELECT TOP 1
            @cOrderKey = OrderKey
         FROM dbo.PackHeader PH WITH (NOLOCK) 
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.Storerkey = @cStorer 
         AND   PD.DropID = @cDropID

      -- Validate drop ID
      IF @cOrderKey = '' OR @cOrderKey IS NULL
      BEGIN
         SET @nErrNo = 66752
         SET @cErrMsg = rdt.rdtgetmessage( 66752, @cLangCode, 'DSP') --Invalid DropID
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cDropID = ''
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS ( SELECT TOP 1 1 
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Storerkey = @cStorer
         AND   Orderkey = @cOrderKey)
      BEGIN
         SET @nErrNo = 66741
         SET @cErrMsg = rdt.rdtgetmessage( 66741, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cDropID = ''
         GOTO Step_1_Fail    
      END

      SELECT @cLoadKey = Loadkey,
             @cConsigneeKey = ConsigneeKey   -- (james02)
      FROM dbo.Orders WITH (NOLOCK)
      WHERE Storerkey = @cStorer 
      AND   Orderkey = @cOrderKey

      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      --WHERE OrderKey = @cOrderKey 
      WHERE ExternOrderkey = @cLoadKey 

		-- SOS#145273 Start
		SET @cNoLoadPlan = ''
		SET @cNoLoadPlan = rdt.RDTGetConfig( @nFunc, 'NoLoadPlan', @cStorer) 
		-- SOS#145273 End

      -- (Vicky02) - Start
      IF ISNULL(RTRIM(@cPickSlipNo), '') = '' AND @cNoLoadPlan <> '1'	--SOS#145273
      BEGIN
          DECLARE C_XD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR --(james01)
          SELECT DISTINCT OD.ExternPOKey
          FROM dbo.OrderDetail OD WITH (NOLOCK)
          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber)
          WHERE PD.DropID = @cDropID
	   
	       OPEN C_XD
        	
	       FETCH NEXT FROM C_XD INTO @cExternPOKey
        	
	       WHILE @@FETCH_STATUS <> -1 
	       BEGIN
              SELECT @cPickSlipNo = PickHeaderKey
              FROM dbo.PickHeader WITH (NOLOCK)
              WHERE ExternOrderkey = @cExternPOKey

              IF ISNULL(RTRIM(@cPickSlipNo), '') = ''
              BEGIN
                 SET @cNo_PSNO = 'Y'
                 GOTO EXIT_XD
              END

         	 FETCH NEXT FROM C_XD INTO @cExternPOKey
   	    END
          EXIT_XD:
		    CLOSE C_XD
		    DEALLOCATE C_XD 

          IF @cNo_PSNO = 'Y'
          BEGIN
             SET @nErrNo = 66742
             SET @cErrMsg = rdt.rdtgetmessage( 66742, @cLangCode,'DSP') -- No PSNO
             EXEC rdt.rdtSetFocusField @nMobile, 2
             SET @cDropID = ''
             GOTO Step_1_Fail
          END
      END
		--SOS#145273
      ELSE
			SET @cNoLoadPlan = ''      


      -- Get picking info
--      SELECT TOP 1
--         @dScanInDate = ScanInDate
--      FROM dbo.PickingInfo WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo

-- Comment by (Vicky01) - Start
      -- Validate pickslip not scan in
--      IF @dScanInDate IS NULL
--      BEGIN
--         SET @nErrNo = 66743
--         SET @cErrMsg = rdt.rdtgetmessage( 66743, @cLangCode,'DSP') -- PS not scan in
--         GOTO Step_1_Fail
--      END
-- Comment by (Vicky01) - End


      -- Prepare print screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = '' -- Option
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to print screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:

END
GOTO Quit

/********************************************************************************
Step 2. Screen = 2021
   DROP ID (field02)
   Option  (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField02
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 66744
         SET @cErrMsg = rdt.rdtgetmessage( 66744, @cLangCode, 'DSP') --Option needed
         GOTO Step_2_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2' AND @cOption <> '3' -- (ChewKP01)
			AND @cOption <> '4' -- (GOH01)
      BEGIN
         SET @nErrNo = 66745
         SET @cErrMsg = rdt.rdtgetmessage( 66745, @cLangCode, 'DSP') --Invalid option
         GOTO Step_2_Fail
      END

      -- Validate printer setup
  		IF ISNULL(@cTempPrinter, '') = ''
		BEGIN			
	      SET @nErrNo = 66746
	      SET @cErrMsg = rdt.rdtgetmessage( 66746, @cLangCode, 'DSP') --NoLoginPrinter
	      GOTO Step_2_Fail
		END
		       
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	   FROM RDT.RDTReport WITH (NOLOCK) 
	   WHERE StorerKey = @cStorer
         AND ReportType = CASE WHEN @cOption = '1' THEN 'PLTMNFSTID'  
										 WHEN @cOption = '2' THEN 'LPLabelID' -- (ChewKP01)
										 WHEN @cOption = '3' THEN 'UCCLabel'  -- (ChewKP01)
										 WHEN @cOption = '4' THEN 'CTNMNFSTID'	--(GOH01)
               --ELSE 'LPLabelID' 
								  END
	
      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 66747
         SET @cErrMsg = rdt.rdtgetmessage( 66747, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Step_2_Fail
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 66748
         SET @cErrMsg = rdt.rdtgetmessage( 66748, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Step_2_Fail
      END

      -- Customizable DropID check (james01)
      SET @cDropIDChkSP = rdt.RDTGetConfig( @nFunc, 'PRINTPALLETMAN_CHKSP', @cStorer)    
      IF @cDropIDChkSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDropIDChkSP AND type = 'P')    
         BEGIN    
            SET @cReportType = CASE WHEN @cOption = '1' THEN 'PLTMNFSTID'  
										      WHEN @cOption = '2' THEN 'LPLabelID' 
										      WHEN @cOption = '3' THEN 'UCCLabel'  
										      WHEN @cOption = '4' THEN 'CTNMNFSTID'	
										 END
										 
            SET @cSQL = 'EXEC ' + RTRIM( @cDropIDChkSP) +     
               ' @nMobile, @nFunc, @cLangCode, @cDropID, @cStorer, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile       INT,        ' +    
               '@nFunc         INT,        ' +    
               '@cLangCode     NVARCHAR(3),    ' +    
               '@cDropID       NVARCHAR( 20),  ' +    
               '@cStorer       NVARCHAR( 15),  ' +    
               '@cParam1       NVARCHAR( 20),  ' +    
               '@cParam2       NVARCHAR( 20),  ' +    
               '@cParam3       NVARCHAR( 20),  ' +    
               '@cParam4       NVARCHAR( 20),  ' +    
               '@cParam5       NVARCHAR( 20),  ' +    
               '@nErrNo        INT           OUTPUT, ' +      
               '@cErrMsg       NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @cDropID, @cStorer, @cReportType, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cErrMsg = @cErrMsg
               GOTO Step_2_Fail    
            END    
         END    
      END
      
      DECLARE @tPLTMANDPID AS VariableTable

      BEGIN TRAN

      -- Call printing spooler
		IF @cOption = '3' 
		BEGIN
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cStorer',   @cStorer)
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cDropID',   @cDropID)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorer, '', @cTempPrinter, 
            @cReportType, -- Report type
            @tPLTMANDPID, -- Report params
            'rdtfnc_PrtPltManifest_DropID', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
		END
--GOH01 Start
		ELSE
		IF @cOption = '4'	--GOH01
		BEGIN
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cStorer',   @cStorer)
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cDropID',   @cDropID)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorer, '', @cTempPrinter, 
            @cReportType, -- Report type
            @tPLTMANDPID, -- Report params
            'rdtfnc_PrtPltManifest_DropID', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	      FROM RDT.RDTReport WITH (NOLOCK) 
	      WHERE StorerKey = @cStorer
         AND ReportType = 'UCCLabel'  


         DELETE FROM @tPLTMANDPID
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cStorer',   @cStorer)
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cDropID',   @cDropID)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorer, '', @cTempPrinter, 
            'UCCLabel', -- Report type
            @tPLTMANDPID, -- Report params
            'rdtfnc_PrtPltManifest_DropID', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
            
         IF @cInterCOLBL <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'INTERCOLBL'
                        AND   Code = @cConsigneeKey
                        AND   Storerkey = @cStorer)
            BEGIN
               DELETE FROM @tPLTMANDPID
               INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cStorer',   @cStorer)
               INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cDropID',   @cDropID)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorer, '', @cTempPrinter, 
                  @cInterCOLBL, -- Report type
                  @tPLTMANDPID, -- Report params
                  'rdtfnc_PrtPltManifest_DropID', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END
         END
		END
--GOH01 End
		ELSE
		BEGIN

         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cLoadkey',   @cLoadkey)
         INSERT INTO @tPLTMANDPID (Variable, Value) VALUES ( '@cDropID',   @cDropID)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorer, '', @cTempPrinter, 
            'PLTMANDPID', -- Report type
            @tPLTMANDPID, -- Report params
            'rdtfnc_PrtPltManifest_DropID', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
		END
      

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN

         SET @nErrNo = 66749
         SET @cErrMsg = rdt.rdtgetmessage( 66749, @cLangCode, 'DSP') --'InsertPRTFail'
         GOTO Step_2_Fail
      END

      COMMIT TRAN

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      
      SET @cOutField01 = @cTempPrinter
      SET @cOutField02 = '' -- DropID
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cPickSlipNo   -- DROP ID
      SET @cOutField02 = ''   -- Option
      SET @cOption = ''
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

      StorerKey = @cStorer,
      Facility  = @cFacility,
      --UserName  = @cUserName,
      Printer   = @cPrinter,    

      V_String1 = @cOrderKey,
      V_String2 = @cDropID,
      V_String3 = @cPickslipNo,
      V_String4 = @cLoadkey,
      V_String5 = @cTempPrinter, 
      V_String6 = @cInterCOLBL,
      V_String7 = @cConsigneeKey,

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
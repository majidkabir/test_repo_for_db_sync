SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PrintShopLabel                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print Shop Label                                            */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-04-01 1.0  James    SOS273078 - Created                         */
/* 2013-08-27 1.1  James    SOS287522 - Fix printing seq & label format */
/*                          change (james01)                            */
/* 2013-10-31 1.2  James    SOS294060 - Add Label type (james02)        */
/* 2013-11-13 1.3  ChewKP   Addtional Validation (ChewKP01)             */
/* 2016-09-30 1.4  Ung      Performance tuning                          */  
/* 2018-11-08 1.5  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PrintShopLabel] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cUserName           NVARCHAR( 18),
   @cPrinter            NVARCHAR( 10),
   @cPrinter_Paper      NVARCHAR( 10),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5), 
   @cLoadKey            NVARCHAR( 10),   
   @cReportType         NVARCHAR( 10), 
   @cPrintJobName       NVARCHAR( 50), 
   @cDataWindow         NVARCHAR( 50), 
   @cTargetDB           NVARCHAR( 20), 
   @cLOC                NVARCHAR( 10), 
   @cSKU                NVARCHAR( 20), 
   @cConsigneeKey       NVARCHAR( 15), 
   @cShopNo             NVARCHAR( 5), 
   @cSection            NVARCHAR( 5),
   @cSeparate           NVARCHAR( 5),
   @cDistCenter         NVARCHAR( 5),
   @cBultoNo            NVARCHAR( 5),
   @cMaxBultoNo         NVARCHAR( 5),
   @cMinBultoNo         NVARCHAR( 5),
   @cCheckDigit         NVARCHAR( 1),
   @cTempBarcodeFrom    NVARCHAR( 20),
   @cCode               NVARCHAR( 30),
   @cUDF03              NVARCHAR( 30),
   @cUDF04              NVARCHAR( 30),
   @cSKUFilter          NVARCHAR( 30),
   @cSKUFilterT         NVARCHAR( 30),
   
   @cReportTypeCoverPg     NVARCHAR( 10), 
   @cPrintJobNameCoverPg   NVARCHAR( 50),
   @cDataWindowCoverPg     NVARCHAR( 50),
   @cLabelType             NVARCHAR( 10),    -- (james02)
   @cShopLabelType         NVARCHAR( 10),    -- (james02)
   @cLoadFac               NVARCHAR( 5),     -- (james02)
   @cLabelFac              NVARCHAR( 5),     -- (james02)= ''

   
   @nPrintQty           INT, 
   @nBultoNo            INT, 
   @nNewBultoNo         INT,
   @nTranCount          INT, 
   @nStorePrintQty      INT, 
   @nTtl_ConsigneeKey   INT,              -- (james02)
                   
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

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer, 
   @cPrinter_Paper   = Printer_Paper, 

   @cLoadKey         = V_LoadKey,
   
   @cLabelType       = V_String1,
   @cShopLabelType   = V_String2,
   
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

IF @nFunc = 592 -- Print Shop Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 592
   IF @nStep = 1 GOTO Step_1   -- Scn = 3550. LoadKey
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 592. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3550
   SET @nStep = 1

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Prep next screen var
   SET @cLoadKey = ''
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
   -- (Vicky02) - End
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 3550. LoadKey
   LoadKey (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01
      SET @cLabelType = @cInField02

      -- Validate blank
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 80701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LoadKey is req'
         GOTO Step_1_Fail
      END

      -- Check if loadkey is valid
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) 
                     WHERE LoadKey = @cLoadKey
                     AND   Status < '9')
      BEGIN
         SET @nErrNo = 80702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LOADKEY
         GOTO Step_1_Fail
      END

      -- (ChewKP01)
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Facility = @cFacility ) 
      BEGIN
         SET @nErrNo = 80715    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffFacility    
         GOTO Step_1_Fail  
      END
      
      -- (ChewKP01) 
      IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
                      WHERE LPD.LoadKey = @cLoadKey
                      AND O.StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 80716    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffStorer    
         GOTO Step_1_Fail  
      END
      
      -- Check whether the label type choosed   (james02)
      IF ISNULL( @cLabelType, '') = ''
      BEGIN
         SET @nErrNo = 80712
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LABEL TYPE req
         GOTO Quit
      END

      -- Check valid label type
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK) 
                     WHERE ListName = 'SHOPLBLTYP'
                     AND   StorerKey = @cStorerKey
                     AND   Code = @cLabelType)
      BEGIN
         SET @nErrNo = 80713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV LABEL TYPE
         GOTO Quit
      END
      ELSE
      BEGIN
         SELECT @cShopLabelType = Short 
         FROM dbo.CodeLkUp WITH (NOLOCK) 
         WHERE ListName = 'SHPLBLTYPC'
         AND   StorerKey = @cStorerKey
         AND   Code = @cLabelType
         
         IF ISNULL( @cShopLabelType, '') = ''
         BEGIN
            SET @nErrNo = 80714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SHOP LABEL REQ
            GOTO Quit
         END
      END

      -- Check if user select the wrong label type (james02)
      SET @cLoadFac = ''
      SET @cLabelFac = ''
      SELECT @cLoadFac = Facility FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey
      SELECT @cLabelFac = UDF02 FROM dbo.CodeLKUp WITH (NOLOCK) 
      WHERE  ListName = 'SHPLBLTYPC'
      AND    StorerKey = @cStorerKey
      AND    Code = @cLabelType

      IF ISNULL(@cLoadFac, '') <> ISNULL(@cLabelFac, '')
      BEGIN                     
         SET @nErrNo = 80717                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WRONG LBL TYPE                  
         GOTO Quit  
      END           
      
      IF ISNULL(@cPrinter, '') = ''               
      BEGIN                     
         SET @nErrNo = 80703                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter                  
         GOTO Quit  
      END                 
      
      SELECT @cReportType = ISNULL( Long, '')      -- (james02)
      FROM dbo.CodeLkUp WITH (NOLOCK) 
      WHERE ListName = 'SHPLBLTYPC'
      AND   Code = @cLabelType
      AND   StorerKey = @cStorerKey
      
      SET @cPrintJobName = 'PRINT_' + @cReportType -- (james02)      
                  
      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')                   
      FROM RDT.RDTReport WITH (NOLOCK)                   
      WHERE StorerKey = @cStorerKey                  
      AND   ReportType = @cReportType                  
                  
      IF ISNULL(@cDataWindow, '') = ''                  
      BEGIN                  
         SET @nErrNo = 80706                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP                  
         GOTO Step_1_Fail  
      END                  
                        
      IF ISNULL(@cTargetDB, '') = ''                  
      BEGIN          
         SET @nErrNo = 80707                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET                  
         GOTO Quit  
      END                  

      -- Print shop cover page here
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
         @cLabelType, 
         @cStorerKey, 
         @nFunc 
   
      IF @nErrNo <> 0                  
      BEGIN
         SET @nErrNo = 80707                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Print Fail                  
         GOTO Step_1_Fail  
      END                  

      -- Prep next screen var
      SET @cLoadKey = ''
      SET @cOutField01 = ''
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      IF CURSOR_STATUS('LOCAL', 'CUR_HEADER') = 1  
      BEGIN  
         CLOSE CUR_HEADER  
         DEALLOCATE CUR_HEADER  
      END  

      IF CURSOR_STATUS('LOCAL', 'CUR_DETAIL') = 1  
      BEGIN  
         CLOSE CUR_DETAIL  
         DEALLOCATE CUR_DETAIL  
      END  

      SET @cLoadKey = ''
      SET @cOutField01 = '' -- LoadKey
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility, 
      -- UserName       = @cUserName,
      Printer        = @cPrinter,    
      Printer_Paper  = @cPrinter_Paper,   

      V_LoadKey      = @cLoadKey,
      
      V_String1      = @cLabelType,
      V_String2      = @cShopLabelType,
   
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

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15 
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
END

GO
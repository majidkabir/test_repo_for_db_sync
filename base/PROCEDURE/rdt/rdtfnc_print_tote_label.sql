SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/  
/* Store procedure: rdtfnc_Print_Tote_Label                                  */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#178979 - Print Tote Label                                    */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-06-28 1.0  Vicky    Created                                          */  
/* 2010-07-05 1.1  James    1. Pass in param into rdt_bulitprintjob (james01)*/
/* 2010-08-14 1.2  James    Change variable length for target DB (james02)   */
/* 2010-11-26 1.3  James    Only print when totes is not ship/canc (james03) */
/* 2012-09-10 1.4  ChewKP   SOS#255775 StorerConfig for Print Options        */
/*                          (ChewKP01)                                       */
/* 2014-08-04 1.5  CSCHONG  SOS316182 (CS01)                                 */
/* 2014-09-15 1.6  James    Pass value 999 for # of copy for                 */
/*                          kimball printing (james04)                       */
/* 2014-09-19 1.7  James    Allow label to print after mbol (james05)        */
/* 2016-09-30 1.8  Ung      Performance tuning                               */
/* 2018-11-08 1.9  TungGH   Performance                                      */
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_Print_Tote_Label](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
  
-- Misc variable  
DECLARE  
   @b_success           INT  
          
-- Define a variable  
DECLARE    
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR(3),  
   @cPrinter            NVARCHAR(10),  
   @cUserName           NVARCHAR(18),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
  
   @cToteNo             NVARCHAR(18),  
  
   @cReportType         NVARCHAR(10),  
   @cReportType1        NVARCHAR(10),  
   @cReportType2        NVARCHAR(10),  
   @cReportType3        NVARCHAR(10),  
   @cReportType4        NVARCHAR(10),  
   @cReportType5        NVARCHAR(10),  
  
   @cPrintJobName       NVARCHAR(50),  
   @cPrintJobName1      NVARCHAR(50),  
   @cPrintJobName2      NVARCHAR(50),  
   @cPrintJobName3      NVARCHAR(50),  
   @cPrintJobName4      NVARCHAR(50),  
   @cPrintJobName5      NVARCHAR(50),  
  
   @cDataWindow         NVARCHAR(50),  
   @cTargetDB           NVARCHAR(20),  
   @cNoLabelPrinted     NVARCHAR(5),  
   @cOption             NVARCHAR(1),  
  
   @nNoLabelPrinted     INT,
   
   @cDefaultPrintOption NVARCHAR(1), -- (ChewKP01)
 
  
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
  
   @nNoLabelPrinted  = V_Integer1,
      
   @cToteNo          = V_ID,    
   @cReportType      = V_String2,  
   @cReportType1     = V_String3,  
   @cReportType2     = V_String4,  
   @cReportType3     = V_String5,  
   @cReportType4     = V_String6,  
   @cReportType5     = V_String7,  
--   @cPrintJobName    = V_String8,  
--   @cPrintJobName1   = V_String9,  
--   @cPrintJobName2   = V_String10,  
--   @cPrintJobName3   = V_String11,  
--   @cPrintJobName4   = V_String12,  
--   @cPrintJobName5   = V_String13,  
           
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
  
FROM   RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 974  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 874  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2470  Tote No  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2471  Message  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 974)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2470  
   SET @nStep = 1  
  
   -- initialise all variable  
   SET @cToteNo = ''  
  
   SET @nNoLabelPrinted = 0  
  
   SET @cReportType1 = ''  
	SET @cReportType2 = ''  
   SET @cReportType3 = ''  
   SET @cReportType4 = ''  
   SET @cReportType5 = ''  

   SET @cPrintJobName1 = ''  
   SET @cPrintJobName2 = ''  
   SET @cPrintJobName3 = ''  
   SET @cPrintJobName4 = ''  
   SET @cPrintJobName5 = ''  

   -- Prep next screen var     
   SET @cOutField01 = '' 
   
   -- (ChewKP01)
   SET @cDefaultPrintOption = ''
   SET @cDefaultPrintOption = rdt.RDTGetConfig( @nFunc, 'DefaultPrintOption', @cStorerKey) -- 1 / 9 only   
        
   IF ISNULL(@cDefaultPrintOption,'') IN ('1','5')
   BEGIN
      SET @cOutField02 = @cDefaultPrintOption
   END
   ELSE
   BEGIN
      SET @cOutField02 = '1'   
   END
   
   SET @cOutField03 = ''   
   SET @cOutField04 = ''   
   SET @cOutField05 = ''   
   SET @cOutField06 = ''   
   SET @cOutField07 = ''   
   SET @cOutField08 = ''   
   SET @cOutField09 = ''   
   SET @cOutField10 = ''   
   SET @cOutField11 = ''   
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2470  
   TOTE NO (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cToteNo = @cInField01  
      SET @cOption = @cInField02 
  
      IF ISNULL(RTRIM(@cToteNo), '') = ''  
      BEGIN  
         SET @nErrNo = 70341  
         SET @cErrMsg = rdt.rdtgetmessage( 70341, @cLangCode, 'DSP') --TOTE NO req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail    
      END  
  
        -- check exists in PackDetail  
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cToteNo)   
      BEGIN  
         SET @nErrNo = 70342  
         SET @cErrMsg = rdt.rdtgetmessage( 70342, @cLangCode, 'DSP') -- Invalid TOTE NO  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail    
      END  

      -- (james03)
      IF NOT EXISTS (SELECT 1 
	      FROM Orders Orders WITH (NOLOCK) 
         JOIN PACKHEADER PACKHEADER WITH (NOLOCK) 
            ON (Orders.Storerkey = PACKHEADER.Storerkey AND Orders.OrderKey  = PACKHEADER.OrderKey) 
         JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PICKSLIPNO = PACKDETAIL.PICKSLIPNO) 
         JOIN DROPID DROPID WITH (NOLOCK) ON (PACKDETAIL.DROPID = DROPID.DROPID AND DROPID.LOADKEY = ORDERS.LOADKEY) 
         WHERE PACKDETAIL.DropID = @cToteNo )
            --AND ORDERS.Status NOT IN ('CANC','9') )-- (james05)
      BEGIN  
         SET @nErrNo = 70348  
         SET @cErrMsg = rdt.rdtgetmessage( 70348, @cLangCode, 'DSP') --Tote Ship/Canc  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail    
      END  

      IF ISNULL(@cPrinter, '') = ''  
      BEGIN     
         SET @nErrNo = 70343  
         SET @cErrMsg = rdt.rdtgetmessage( 70343, @cLangCode, 'DSP') --NoLoginPrinter  
         GOTO Step_1_Fail  
      END  

      IF ISNULL(RTRIM(@cOption), '') = ''  
      BEGIN  
         SET @nErrNo = 70347  
         SET @cErrMsg = rdt.rdtgetmessage( 70347, @cLangCode, 'DSP') --Option Req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail    
      END  
      /*CS01 Start */
      IF @cOption = '1'
      BEGIN
        -- SET @cReportType1 = 'KIMBALLEUR'  
	    --  SET @cReportType2 = 'KIMBALLGBP'  
       --  SET @cPrintJobName1 = 'PRINT_KIMBALLLABEL_EUR'  
       --  SET @cPrintJobName2 = 'PRINT_KIMBALLLABEL_GBP'  
         SET @cReportType1 = 'KIMBALL'  
	      SET @cReportType2 = 'KIMBALLT3'  
         SET @cPrintJobName1 = 'PRINT_KIMBALLLABEL'  
         SET @cPrintJobName2 = 'PRINT_KIMBALLLABEL_T3'
      END
      ELSE
      BEGIN
	      --SET @cReportType1 = 'KIMBALLGBP'  
        -- SET @cReportType2 = 'KIMBALLEUR'  
         --SET @cPrintJobName1 = 'PRINT_KIMBALLLABEL_GBP'  
        -- SET @cPrintJobName2 = 'PRINT_KIMBALLLABEL_EUR'
         SET @cReportType1 = 'KIMBALLT3'  
	      SET @cReportType2 = 'KIMBALL'  
         SET @cPrintJobName1 = 'PRINT_KIMBALLLABEL_T3'  
         SET @cPrintJobName2 = 'PRINT_KIMBALLLABEL'  
      END
      /*CS01 End*/
      
      /*   SET @cReportType1 = 'KIMBALL'  
	      SET @cReportType2 = 'KIMBALLT3'  
         SET @cPrintJobName1 = 'PRINT_KIMBALLLABEL'  
         SET @cPrintJobName2 = 'PRINT_KIMBALLLABEL_T3'  */

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
      FROM RDT.RDTReport WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = @cReportType1  
  
      IF ISNULL(@cDataWindow, '') = ''  
      BEGIN  
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = @cReportType2  
  
         IF ISNULL(RTRIM(@cDataWindow), '') <> '' AND ISNULL(RTRIM(@cTargetDB), '') <> ''  
         BEGIN  
            SET @cReportType = @cReportType2  
            SET @cPrintJobName = @cPrintJobName2  
         END  
      END  
      ELSE  
      BEGIN  
         SET @cReportType = @cReportType1  
         SET @cPrintJobName = @cPrintJobName1  
      END  
  
      -- Report Type 3,4,5 can be printed together with report type above or it's an option to print 1/2/3/4/5  
      -- Code to be added during future enhancement  
      
      IF ISNULL(@cDataWindow, '') = ''  
      BEGIN  
         SET @nErrNo = 70344  
         SET @cErrMsg = rdt.rdtgetmessage( 70344, @cLangCode, 'DSP') --DWNOTSetup  
         GOTO Step_1a_Fail  
      END  
  
      IF ISNULL(@cTargetDB, '') = ''  
      BEGIN  
         SET @nErrNo = 70345  
         SET @cErrMsg = rdt.rdtgetmessage( 70345, @cLangCode, 'DSP') --TgetDB Not Set  
         GOTO Step_1a_Fail  
      END  
  
     

      SELECT @nNoLabelPrinted = ISNULL(SUM(PackDetail.QTY), 0)  
	   FROM Orders Orders WITH (NOLOCK) 
      JOIN PACKHEADER PACKHEADER WITH (NOLOCK) 
         ON (Orders.Storerkey = PACKHEADER.Storerkey AND Orders.OrderKey  = PACKHEADER.OrderKey) 
      JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PICKSLIPNO = PACKDETAIL.PICKSLIPNO) 
      JOIN DROPID DROPID WITH (NOLOCK) ON (PACKDETAIL.DROPID = DROPID.DROPID AND DROPID.LOADKEY = ORDERS.LOADKEY) 
      WHERE PACKDETAIL.DropID = @cToteNo 
  
       BEGIN TRAN  
      SET @nErrNo = 0 
      IF @cReportType1  = 'KIMBALL'
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
            @cStorerKey,          --(CS01)
            '',                   --(CS01)
   --         @nNoLabelPrinted,                    --(CS01)
            '999',                --(james04)
            @cToteNo      -- parameter 1 (by ref) james01  
      ELSE
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
            @cStorerKey,          --(CS01)
            '',                   --(CS01)
            @nNoLabelPrinted,                    --(CS01)
            @cToteNo      -- parameter 1 (by ref) james01  
  
      IF @nErrNo <> 0  
      BEGIN  
         ROLLBACK TRAN  
  
         SET @nErrNo = 70346  
         SET @cErrMsg = rdt.rdtgetmessage( 70346, @cLangCode, 'DSP') --'InsertPRTFail'  
         GOTO Step_1a_Fail  
      END  
      ELSE  
      BEGIN  
         COMMIT TRAN  
      END  
  
--      (james03)
--      SELECT @nNoLabelPrinted = SUM(QTY)  
--      FROM dbo.PackDetail WITH (NOLOCK)  
--      WHERE DropID = @cToteNo  
  
      SELECT @nNoLabelPrinted = ISNULL(SUM(PackDetail.QTY), 0)  
	   FROM Orders Orders WITH (NOLOCK) 
      JOIN PACKHEADER PACKHEADER WITH (NOLOCK) 
         ON (Orders.Storerkey = PACKHEADER.Storerkey AND Orders.OrderKey  = PACKHEADER.OrderKey) 
      JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PICKSLIPNO = PACKDETAIL.PICKSLIPNO) 
      JOIN DROPID DROPID WITH (NOLOCK) ON (PACKDETAIL.DROPID = DROPID.DROPID AND DROPID.LOADKEY = ORDERS.LOADKEY) 
      WHERE PACKDETAIL.DropID = @cToteNo 
         --AND ORDERS.Status NOT IN ('CANC','9') 

      --prepare next screen variable  
      SET @cOutField01 = @cToteNo  
      SET @cOutField02 = CAST(@nNoLabelPrinted AS CHAR)  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''   
      SET @cOutField02 = ''   
      SET @cOutField03 = ''   
      SET @cOutField04 = ''   
      SET @cOutField05 = ''   
      SET @cOutField06 = ''   
      SET @cOutField07 = ''   
      SET @cOutField08 = ''   
      SET @cOutField09 = ''   
      SET @cOutField10 = ''   
      SET @cOutField11 = ''   
  
      SET @cToteNo = ''  
      SET @cReportType = ''  
      SET @cPrintJobName = ''  
      SET @cDataWindow = ''   
      SET @cTargetDB = ''  
      SET @nNoLabelPrinted = 0  
   END  
   
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cToteNo = ''  
  
      SET @cOutField01 = ''  
   END  
   Step_1a_Fail:  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. screen = 2471  
 Message Screen  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC  
   BEGIN  
      --prepare next screen variable  
      SET @cOutField01 = ''  
      --SET @cOutField02 = '1'  
      
      -- (ChewKP01)
      SET @cDefaultPrintOption = ''
      SET @cDefaultPrintOption = rdt.RDTGetConfig( @nFunc, 'DefaultPrintOption', @cStorerKey) -- 1 / 9 only   
           
      IF ISNULL(@cDefaultPrintOption,'') IN ('1','9')
      BEGIN
         SET @cOutField02 = @cDefaultPrintOption
      END
      ELSE
      BEGIN
         SET @cOutField02 = '1'   
      END
  
      SET @cToteNo = ''  
      SET @cReportType = ''  
      SET @cPrintJobName = ''  
      SET @cDataWindow = ''   
      SET @cTargetDB = ''  
      SET @nNoLabelPrinted = 0 
      SET @cOption = '' 
      
      
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,   
       Func          = @nFunc,  
       Step          = @nStep,              
       Scn           = @nScn,  
  
       StorerKey     = @cStorerKey,  
       Facility      = @cFacility,   
       Printer       = @cPrinter,      
       -- UserName      = @cUserName,  
     
       V_Integer1    = @nNoLabelPrinted,
       
       V_ID          = @cToteNo,             
       V_String2     = @cReportType,     
       V_String3     = @cReportType1,    
       V_String4     = @cReportType2,    
       V_String5     = @cReportType3,    
       V_String6     = @cReportType4,    
       V_String7     = @cReportType5,    
--       V_String8     = @cPrintJobName,  
--       V_String9     = @cPrintJobName1,  
--       V_String10    = @cPrintJobName2,  
--       V_String11    = @cPrintJobName3,  
--       V_String12    = @cPrintJobName4,  
--       V_String13    = @cPrintJobName5,       
  
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
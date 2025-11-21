SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/    
/* Store procedure: rdtfnc_CC_ReprintToteLabel                               */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: SOS#202459 - Reprint Manifest and Tote Label                     */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2011-02-07 1.0  ChewKP   Created                                          */    
/* 2011-04-16 1.1  James    1. Close Tote after manifest prints (james01)    */    
/*                          2. Add extra tote validation                     */
/* 2016-09-30 1.2  Ung      Performance tuning                               */
/* 2018-10-30 1.3  Gan      Performance tuning                               */
/*****************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_CC_ReprintToteLabel](    
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
   @cPrinter_Paper      NVARCHAR(10),    
   @cUserName           NVARCHAR(18),    
    
   @cStorerKey          NVARCHAR(15),    
   @cFacility           NVARCHAR(5),    
    
   @cToToteNo           NVARCHAR(18),    
   @cOption             NVARCHAR(1),    
   @cReportType         NVARCHAR(10),    
   @cPrintJobName       NVARCHAR(50),    
   @cDataWindow         NVARCHAR(50),    
   @cTargetDB           NVARCHAR(20),    
   @nReprintOption      INT,    
   @cManifestPrinted    NVARCHAR(10),    
    
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
   @cPrinter_Paper   = Printer_Paper,     
   @cUserName        = UserName,    
   
   @nReprintOption   = V_Integer1,
    
   @cToToteNo        = V_String1,    
   @cOption          = V_String2,    
  -- @nReprintOption   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,            
          
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
IF @nFunc = 1781
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1781
   IF @nStep = 1 GOTO Step_1   -- Scn = 2650 Tote No    
   IF @nStep = 2 GOTO Step_2   -- Scn = 2651 Print Option    
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from menu (func = 1781)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn  = 2650    
   SET @nStep = 1    
    
       
   SET @nReprintOption = 0    
    
   -- initialise all variable    
   SET @cToToteNo = ''    
   SET @cOption = ''    
    
   -- Prep next screen var       
   SET @cOutField01 = ''     
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. screen = 2650    
   Tote No: (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cToToteNo = @cInField01    
    
      --When Lane is blank    
      IF @cToToteNo = ''    
      BEGIN    
         SET @nErrNo = 72141    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote No req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail      
      END     
    
      --Check if Tote No Exists    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cToToteNo)    
      BEGIN    
          SET @nErrNo =  72142   
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNotExists    
          EXEC rdt.rdtSetFocusField @nMobile, 1    
          GOTO Step_1_Fail      
      END    

      --Check if Tote No Exists    
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
         WHERE DropID = @cToToteNo
            AND DropIDType = 'C&C')    
      BEGIN    
          SET @nErrNo =  72158   
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOT C&C TOTE    
          EXEC rdt.rdtSetFocusField @nMobile, 1    
          GOTO Step_1_Fail      
      END    

      --IF @nReprintOption = 0    
      --BEGIN    
--         IF EXISTS(    
--            SELECT 1 FROM DROPID WITH (NOLOCK)     
--            WHERE DropID = @cToToteNo    
--            AND LabelPrinted = 'Y' AND ManifestPrinted='Y')    
--         BEGIN    
--             SET @nErrNo = 70585    
--             SET @cErrMsg = rdt.rdtgetmessage( 70585, @cLangCode, 'DSP') --LabelPrinted    
--             EXEC rdt.rdtSetFocusField @nMobile, 1    
--             GOTO Step_1_Fail               
--         END    
    
         -- (james01)    
         -- If exists dropid which is not shipped/canc and is store ppa tote     
         -- not allow to close tote. it must use pts store sort module to pack and close  
         -- Ignore Message02 (From Tote#) for Tote Consolidation   
--         IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)     
--                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey    
--                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey    
--                    JOIN dbo.DROPID D WITH (NOLOCK) ON TD.DROPID = D.DROPID and O.LoadKey = D.LoadKey    
--                    WHERE TD.DropID = @cToToteNo    
--                       AND TD.PickMethod = 'PIECE'    
--                       AND O.StorerKey = @cStorerKey    
--                       AND O.Status NOT IN ('9', 'CANC')   
--                       AND TD.Message02=''  -- (SHONG01)
--                       AND D.LabelPrinted <> 'Y')  -- (SHONG02)  
--         BEGIN    
--             SET @nErrNo = 70578    
--             SET @cErrMsg = rdt.rdtgetmessage( 70578, @cLangCode, 'DSP') --DO PTS 2 CLOSE    
--             EXEC rdt.rdtSetFocusField @nMobile, 1    
--             GOTO Step_1_Fail               
--         END    
      --END    
    
      --prepare next screen variable    
      SET @cOutField08 = ''    
    
      
    
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
    
      SET @cToToteNo = ''    
      SET @cOption = ''    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cToToteNo = ''    
      SET @cOption = ''    
    
      SET @cOutField01 = ''    
    END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. screen = 2651    
   Option (Field01)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField01    
    
      IF ISNULL(@cOption, '') = ''    
      BEGIN    
         SET @nErrNo = 72143    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail      
      END     
    
      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '9'    
      BEGIN    
         SET @nErrNo = 72144    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail      
      END     
    
      IF @cOption = '1'    
      BEGIN    
         -- Printing process    
       
    
             
         --IF @nReprintOption = 0    
         --BEGIN    
--            IF EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo    
--                          AND LabelPrinted = 'Y')     
--            BEGIN    
--               SET @cReportType = 'SORTLABEL'    
--               SET @cPrintJobName = 'PRINT_SORTLABEL'    
--    
--               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
--                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
--               FROM RDT.RDTReport WITH (NOLOCK)     
--               WHERE StorerKey = @cStorerKey    
--               AND   ReportType = @cReportType    
--    
--               IF ISNULL(@cDataWindow, '') = ''    
--               BEGIN    
--                  SET @nErrNo = 72146
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
--                  GOTO Step_2_Fail    
--               END    
--    
--               IF ISNULL(@cTargetDB, '') = ''    
--               BEGIN    
--                  SET @nErrNo = 72147    
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDBNotSet    
--                  GOTO Step_2_Fail    
--               END    
--    
--               BEGIN TRAN    
--    
--               SET @nErrNo = 0    
--               EXEC RDT.rdt_BuiltPrintJob     
--                  @nMobile,    
--                  @cStorerKey,    
--                  @cReportType,    
--                  @cPrintJobName,    
--                  @cDataWindow,    
--                  @cPrinter,    
--                  @cTargetDB,    
--                  @cLangCode,    
--                  @nErrNo  OUTPUT,    
--                  @cErrMsg OUTPUT,    
--                  @cStorerKey,    
--                  @cToToteNo    
--    
--               IF @nErrNo <> 0    
--               BEGIN    
--                  SET @nErrNo = 72148    
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'    
--                  ROLLBACK TRAN    
--                  GOTO Step_2_Fail    
--               END    
--                 
--            END    
         --END                
    
             
         IF @nReprintOption = 0    
         BEGIN    
--            IF EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo    
--                          AND ManifestPrinted = 'Y')    
--            BEGIN    
               SET @cReportType = 'CCMANFES'    
               SET @cPrintJobName = 'PRINT_CCMANFES'    
    
               IF ISNULL(@cPrinter_Paper, '') = ''    
               BEGIN    
                  SET @nErrNo = 72149    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter    
                   GOTO Step_2_Fail    
               END    
    
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
               FROM RDT.RDTReport WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey    
               AND   ReportType = @cReportType    
    
               IF ISNULL(@cDataWindow, '') = ''    
               BEGIN    
                  SET @nErrNo = 72150    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
                  GOTO Step_2_Fail    
               END    
    
               IF ISNULL(@cTargetDB, '') = ''    
               BEGIN    
                  SET @nErrNo = 72151    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDBNotSet    
                  GOTO Step_2_Fail    
               END    
    
               BEGIN TRAN    
    
               SET @nErrNo = 0    
               EXEC RDT.rdt_BuiltPrintJob     
                  @nMobile,    
                  @cStorerKey,    
                  @cReportType,    
                  @cPrintJobName,    
                  @cDataWindow,    
                  @cPrinter_Paper,     
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,    
                  @cStorerKey,    
                  @cToToteNo    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @nErrNo = 72152    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'    
                  ROLLBACK TRAN    
                  GOTO Step_2_Fail    
               END    
               
               SET @cManifestPrinted = ''
               SELECT @cManifestPrinted = ManifestPrinted
               FROM dbo.DROPID WITH (NOLOCK) 
               WHERE DropID = @cToToteNo    
               
               IF @cManifestPrinted <> 'Y'
               BEGIN
                  BEGIN TRAN
                     
                  UPDATE dbo.DropID 
                  SET ManifestPrinted = 'Y' 
                  WHERE DropID = @cToToteNo
                  
                  IF @nErrNo <> 0    
                  BEGIN    
                     SET @nErrNo = 72156    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'    
                     ROLLBACK TRAN    
                     GOTO Step_2_Fail    
                  END    
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END

               -- (james01)
               IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) 
                  WHERE DropID = @cToToteNo
                     AND Status < '9')
               BEGIN
                  BEGIN TRAN
                     
                  UPDATE dbo.DropID 
                  SET Status = '9'   
                  WHERE DropID = @cToToteNo
                  
                  IF @nErrNo <> 0    
                  BEGIN    
                     SET @nErrNo = 72157    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CloseToteFail'    
                     ROLLBACK TRAN    
                     GOTO Step_2_Fail    
                  END    
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END
               

                                   
--            END    
         END    
--         ELSE    
--         BEGIN    
--            -- Only allow to reprint if tote is closed (james02)    
--            IF NOT EXISTS (SELECT 1 FROM DROPID WITH (NOLOCK)     
--               WHERE DropID = @cToToteNo    
--               AND   ManifestPrinted='Y' )    
--            BEGIN    
--               SET @nErrNo = 70583    
--               SET @cErrMsg = rdt.rdtgetmessage( 70583, @cLangCode, 'DSP') --CLOSE TOTE 1ST    
--               EXEC rdt.rdtSetFocusField @nMobile, 1     
--               GOTO Step_2_Fail               
--            END    
--  
--            IF @nFunc = 1778
--            BEGIN
--               SET @cReportType = 'SORTMANFES'    
--               SET @cPrintJobName = 'PRINT_SORTMANFES'    
--            END
--            ELSE
--            IF @nFunc = 1780  -- (james03)
--            BEGIN
--               SET @cReportType = 'RPRTMANFES'    
--               SET @cPrintJobName = 'PRINT_RPRTMANFES'    
--            END
--
--            IF ISNULL(@cPrinter_Paper, '') = ''    
--            BEGIN    
--               SET @nErrNo = 70579    
--               SET @cErrMsg = rdt.rdtgetmessage( 70579, @cLangCode, 'DSP') --NoPaperPrinter    
--                GOTO Step_2_Fail    
--            END    
--    
--            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
--                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
--            FROM RDT.RDTReport WITH (NOLOCK)     
--            WHERE StorerKey = @cStorerKey    
--            AND   ReportType = @cReportType    
--    
--            IF ISNULL(@cDataWindow, '') = ''    
--            BEGIN    
--               SET @nErrNo = 70580    
--               SET @cErrMsg = rdt.rdtgetmessage( 70580, @cLangCode, 'DSP') --DWNOTSetup    
--               GOTO Step_2_Fail    
--            END    
--    
--            IF ISNULL(@cTargetDB, '') = ''    
--            BEGIN    
--               SET @nErrNo = 70581    
--               SET @cErrMsg = rdt.rdtgetmessage( 70581, @cLangCode, 'DSP') --TgetDBNotSet    
--               GOTO Step_2_Fail    
--            END    
--    
--            BEGIN TRAN    
--    
--            SET @nErrNo = 0    
--            EXEC RDT.rdt_BuiltPrintJob     
--               @nMobile,    
--               @cStorerKey,    
--               @cReportType,    
--               @cPrintJobName,    
--               @cDataWindow,    
--               @cPrinter_Paper,     
--               @cTargetDB,    
--               @cLangCode,    
--               @nErrNo  OUTPUT,    
--               @cErrMsg OUTPUT,    
--               @cStorerKey,    
--               @cToToteNo    
--    
--            IF @nErrNo <> 0    
--            BEGIN    
--               SET @nErrNo = 70582    
--               SET @cErrMsg = rdt.rdtgetmessage( 70582, @cLangCode, 'DSP') --'InsertPRTFail'    
--               ROLLBACK TRAN    
--               GOTO Step_2_Fail    
--            END    
--    
            COMMIT TRAN    
--         END    
             
         SET @cOutField05 = ''    
    
         SET @cToToteNo = ''    
         SET @cOption = ''    
    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
    
      IF @cOption = '9'    
      BEGIN    
         --IF @nReprintOption = 1  
         --BEGIN  
--            IF @nFunc = 1778
--            BEGIN
               SET @cReportType = 'CCTOTELBL'    
               SET @cPrintJobName = 'PRINT_CCTOTELBL'    
--            END
--            ELSE
--            IF @nFunc = 1780  -- (james03)
--            BEGIN
--               SET @cReportType = 'RPRTLABEL'    
--               SET @cPrintJobName = 'PRINT_RPRTLABEL'    
--            END
            IF ISNULL(@cPrinter, '') = ''    
            BEGIN       
                  SET @nErrNo = 72145    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter    
                  GOTO Step_2_Fail    
            END    
       
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
            FROM RDT.RDTReport WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey    
            AND   ReportType = @cReportType    
  
            IF ISNULL(@cDataWindow, '') = ''    
            BEGIN    
               SET @nErrNo = 72153    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
               GOTO Step_2_Fail    
            END    
       
            IF ISNULL(@cTargetDB, '') = ''    
            BEGIN    
               SET @nErrNo = 72154    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDBNotSet    
               GOTO Step_2_Fail    
            END    
  
            BEGIN TRAN    
  
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
               @cStorerKey,    
               @cToToteNo    
  
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 72155    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'    
               ROLLBACK TRAN    
               GOTO Step_2_Fail    
            END    
                                                  
            COMMIT TRAN    
         --END  
  
         SET @cOutField05 = ''     
    
         
         SET @cToToteNo = ''    
         SET @cOption = ''    
    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END      -- @cOption = '9'    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = ''    
    
      SET @cToToteNo = ''    
      SET @cOption = ''    
  
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cOption = ''    
    
      SET @cOutField01 = ''    
   END    
    
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
       Printer_Paper = @cPrinter_Paper,     
       -- UserName      = @cUserName,  
       
       V_Integer1    = @nReprintOption,
    
       V_String1     = @cToToteNo,    
       V_String2     = @cOption,    
       --V_String3     = @nReprintOption,    
    
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
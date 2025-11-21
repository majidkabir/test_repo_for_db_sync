SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/    
/* Store procedure: rdtfnc_Reprint_CasePiece_Label                           */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: SOS#216093 - Reprint Case/Piece Label                            */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2011-05-10 1.0  James    Created                                          */ 
/* 2016-09-30 1.1  Ung      Performance tuning                               */    
/* 2018-11-13 1.2  Gan      Peeformance tuning                               */
/*****************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_Reprint_CasePiece_Label](    
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
   @cLangCode           NVARCHAR( 3),    
   @nMenu               INT,    
   @nInputKey           NVARCHAR( 3),    
   @cPrinter            NVARCHAR( 10),    
   @cPrinter_Paper      NVARCHAR( 10),    
   @cUserName           NVARCHAR( 18),    
    
   @cStorerKey          NVARCHAR( 15),    
   @cFacility           NVARCHAR( 5),    
    
   @cPickSlipNo         NVARCHAR( 10),    
   @cFromCTN            NVARCHAR( 5),
   @cToCTN              NVARCHAR( 5),
   @cOption             NVARCHAR( 1),    
   @cReportType         NVARCHAR( 10),    
   @cPrintJobName       NVARCHAR( 50),    
   @cDataWindow         NVARCHAR( 50),    
   @cTargetDB           NVARCHAR( 20),    
   @cLabelType          NVARCHAR( 10),    
   @nFromCTN            INT, 
   @nToCTN              INT, 
   @nCartonNo           INT, 

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
   @cPickSlipNo      = V_PickSlipNo,

   @cLabelType       = V_String1,    
   @cFromCTN         = V_String2, 
   @cToCTN           = V_String3, 

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
IF @nFunc = 622
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 622
   IF @nStep = 1 GOTO Step_1   -- Scn = 2810 Option    
   IF @nStep = 2 GOTO Step_2   -- Scn = 2811 PickSlip, From Carton, To Carton    
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from menu (func = 1781)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn  = 2810    
   SET @nStep = 1    
    
   -- initialise all variable    
   SET @cLabelType = ''    
   SET @cOption = ''    
    
   -- Prep next screen var       
   SET @cOutField01 = ''     
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. screen = 2810    
   Option: (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField01    
    
      --Check blank    
      IF ISNULL(@cOption, '') = ''    
      BEGIN    
         SET @nErrNo = 73066    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req    
         GOTO Step_1_Fail      
      END     

      --Check valid option
      IF @cOption NOT IN ('1', '2')    
      BEGIN    
         SET @nErrNo = 73067    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option 
         GOTO Step_1_Fail      
      END     

      SET @cLabelType = ''
      SET @cLabelType = CASE WHEN @cOption = '1' THEN 'CASE' ELSE 'PIECE' END
    
      --prepare next screen variable    
      SET @cOutField01 = CASE WHEN @cOption = '1' THEN 'REPRINT CASE LABEL' ELSE 'REPRINT PIECE LABEL' END    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      EXEC rdt.rdtSetFocusField @nMobile, 2    

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
    
      SET @cOption = ''    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cOption = ''    
    
      SET @cOutField01 = ''    
    END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. screen = 2811    
   PickSlip       (Field01, input)    
   From Carton    (Field01, input)    
   To Carton      (Field01, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cPickSlipNo = ''    
      SET @cFromCTN = ''    
      SET @cToCTN = ''    

      SET @cPickSlipNo = @cInField02    
      SET @cFromCTN = @cInField03    
      SET @cToCTN = @cInField04    
    
      IF ISNULL(@cPickSlipNo, '') = ''    
      BEGIN    
         SET @nErrNo = 73068    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIP req   
         SET @cOutField02 = ''
         SET @cOutField03 = @cFromCTN
         SET @cOutField04 = @cToCTN
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Quit      
      END     

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo)
      BEGIN    
         SET @nErrNo = 73069    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKSLIP    
         SET @cOutField02 = ''
         SET @cOutField03 = @cFromCTN
         SET @cOutField04 = @cToCTN
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Quit      
      END     

      -- Blank taken as 0
      IF ISNULL(@cFromCTN, '') = '' SET @cFromCTN = '0'

      IF rdt.rdtIsValidQty(@cFromCTN, 1) = 0
      BEGIN    
         SET @nErrNo = 73070    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv FROM CTN    
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = ''
         SET @cOutField04 = @cToCTN
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         GOTO Quit      
      END     

      SET @nFromCTN = 0
      SET @nFromCTN = CAST(@cFromCTN AS INT)

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo
                        AND CartonNo = @nFromCTN)
      BEGIN    
         SET @nErrNo = 73071    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv FROM CTN    
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = ''
         SET @cOutField04 = @cToCTN
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         GOTO Quit      
      END     

      IF ISNULL(@cToCTN, '') <> ''
      BEGIN
         IF rdt.rdtIsValidQty(@cToCTN, 1) = 0
         BEGIN    
            SET @nErrNo = 73072    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TO CTN    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO Quit      
         END     

         SET @nToCTN = 0
         SET @nToCTN = CAST(@cToCTN AS INT)

         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                           AND PickSlipNo = @cPickSlipNo
                           AND CartonNo = @nToCTN)
         BEGIN    
            SET @nErrNo = 73073    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TO CTN    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO Quit      
         END  
   
         IF @nFromCTN > @nToCTN
         BEGIN    
            SET @nErrNo = 73082    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FROM > TO CTN    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO Quit      
         END     
      END

      -- Printing process    
      IF @nToCTN > '0'    -- Print > 1 copy
      BEGIN    
         IF ISNULL(@cPrinter, '') = ''                
         BEGIN                   
            SET @nErrNo = 73074                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter                
            GOTO Quit              
         END                

         IF @cLabelType = 'CASE'
         BEGIN
            SET @cReportType = 'CTNMARKLBL'    
            SET @cPrintJobName = 'PRINT_CARTON_CASE_LABEL'    
         END
         ELSE
         BEGIN
            SET @cReportType = 'UCCLABEL'    
            SET @cPrintJobName = 'PRINT_CARTON_PIECE_LABEL'    
         END

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
         FROM RDT.RDTReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = @cReportType    
    
         IF ISNULL(@cDataWindow, '') = ''    
         BEGIN    
            SET @nErrNo = 73075
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = @cToCTN
            GOTO Quit    
         END    
    
         IF ISNULL(@cTargetDB, '') = ''    
         BEGIN    
            SET @nErrNo = 73076    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDBNotSet    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = @cToCTN
            GOTO Quit    
         END    
    
         BEGIN TRAN    

         DECLARE CUR_PRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT CartonNo FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND CartonNo BETWEEN @nFromCTN AND @nToCTN
         OPEN CUR_PRINT
         FETCH NEXT FROM CUR_PRINT INTO @nCartonNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN

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
               @cPickSlipNo,
               @nCartonNo 

            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 73077    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'    
               ROLLBACK TRAN    
               CLOSE CUR_PRINT
               DEALLOCATE CUR_PRINT
               SET @cOutField02 = @cPickSlipNo
               SET @cOutField03 = @cFromCTN
               SET @cOutField04 = @cToCTN
               GOTO Quit    
            END    

            FETCH NEXT FROM CUR_PRINT INTO @nCartonNo
         END    
         CLOSE CUR_PRINT
         DEALLOCATE CUR_PRINT
      END                
      ELSE
      BEGIN    -- Print 1 copy
         IF ISNULL(@cPrinter, '') = ''                
         BEGIN                   
            SET @nErrNo = 73078                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter                
            GOTO Quit              
         END                

         IF @cLabelType = 'CASE'
         BEGIN
            SET @cReportType = 'CTNMARKLBL'    
            SET @cPrintJobName = 'PRINT_CARTON_CASE_LABEL'    
         END
         ELSE
         BEGIN
            SET @cReportType = 'UCCLABEL'    
            SET @cPrintJobName = 'PRINT_CARTON_PIECE_LABEL'    
         END

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
         FROM RDT.RDTReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = @cReportType    
    
         IF ISNULL(@cDataWindow, '') = ''    
         BEGIN    
            SET @nErrNo = 73079
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = @cToCTN
            GOTO Quit    
         END    
    
         IF ISNULL(@cTargetDB, '') = ''    
         BEGIN    
            SET @nErrNo = 73080    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDBNotSet    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = @cToCTN
            GOTO Quit    
         END    
    
         SET @nCartonNo = @nFromCTN

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
            @cPickSlipNo,
            @nCartonNo 

         IF @nErrNo <> 0    
         BEGIN    
            SET @nErrNo = 73081    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'    
            ROLLBACK TRAN    
            SET @cOutField02 = @cPickSlipNo
            SET @cOutField03 = @cFromCTN
            SET @cOutField04 = @cToCTN
            GOTO Quit    
         END    
      END

      COMMIT TRAN    
             
      SET @cOutField01 = ''    
 
      SET @cOption = ''    
      SET @cLabelType = ''
 
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = ''    
    
      SET @cOption = ''    
      SET @cLabelType = ''
  
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
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET    
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
       
       V_PickSlipNo  = @cPickSlipNo, 
    
       V_String1     = @cLabelType,    
       V_String2     = @cFromCTN, 
       V_String3     = @cToCTN, 
    
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Copyright: IDS                                                       */  
/* Purpose: UCC Info                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-03-22 1.0  ChewKP     Created. SOS#365640                       */ 
/* 2016-09-30 1.1  Ung        Performance tuning                        */    
/* 2017-03-07 1.2  ChewKP     Remove Traceinfo Insert                   */
/* 2018-10-17 1.3  Tung GH    Performance                               */
/************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_UCCInfo] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
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
   @nFunc      INT,  
   @nScn       INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @nInputKey  INT,  
   @nMenu      INT,  
  
   @cStorerKey NVARCHAR( 15),  
   @cFacility  NVARCHAR( 5),   
   @cPrinter   NVARCHAR( 10),  
  
   @b_success  INT,  
   @n_err      INT,       
   @c_errmsg   NVARCHAR( 250),   
   
   @cExecStatements  NVARCHAR(4000),      
   @cExecArguments   NVARCHAR(4000),     
     
   @cParm1 NVARCHAR(20),  
   @cParm2 NVARCHAR(20),  
   @cParm3 NVARCHAR(20),  
   @cParm4 NVARCHAR(20),  
   @cParm5 NVARCHAR(20),  
   @cParm6 NVARCHAR(20),  
   @cParm7 NVARCHAR(20),  
   @cParm8 NVARCHAR(20),  
   @cParm9 NVARCHAR(20),  
   @cParm10 NVARCHAR(20),  
     
   @cValidate NVARCHAR(1),  
   @cValidateField NVARCHAR(20),  
   @cDisplaySQLStatement NVARCHAR(4000),   
   @cValidateTable NVARCHAR(20),   
   @cRefNo    NVARCHAR(20),  
   @cUCCNo    NVARCHAR(20),  
   @nPassValidation  INT,  
     
  
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)  
  
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
   @cPrinter   = Printer,   
  
   @cRefNo       = V_String1,  
  
  
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc = 726  -- Data capture #3  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- UCC Info  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4550. LOC  
     
END  
  
--RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. func = 726. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
     
     
   -- Set the entry point  
   SET @nScn = 4550  
   SET @nStep = 1  
  
   -- Initiate var  
   SET @cRefNo = ''  
   SET @cUCCNo = ''  
   
   SELECT @cValidate = Short   
   FROM dbo.CodeLkup WITH (NOLOCK)   
   WHERE ListName = 'UCCINFO'  
   AND Code = '1'  
   AND StorerKey = @cStorerKey  
     
   -- Init screen  
   SET @cOutField01 = ''   
   SET @cOutField02 = ''   
   
   IF ISNULL(@cValidate,'') = '1'  
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   ELSE
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   
   
     
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. Scn = 1770. LOC  
   LOC      (field01, input)  
   REFERENCE(field02, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      --screen mapping  
    SET @cRefNo = ISNULL(@cInField01,'')   
    SET @cUCCNo = ISNULL(@cInField02,'')   
  
  
      SELECT @cValidate = Short   
            ,@cValidateTable = Long   
            ,@cValidateField = UDF01  
            --,@cDisplaySQLStatement = Notes  
      FROM dbo.CodeLkup WITH (NOLOCK)   
      WHERE ListName = 'UCCINFO'  
      AND Code = '1'  
      AND StorerKey = @cStorerKey  
  
     
  
        
      IF ISNULL(@cValidate,'') = '1'  
      BEGIN   
           
         IF @cRefNo = ''   
         BEGIN  
            SET @cRefNo = ''  
            SET @cUCCNo = ''
            SET @nErrNo = 98153  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNoReq  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
           
         SET @nPassValidation = 0  
         
         --INSERT INTO TraceInfo (TraceName , TimeIn, Col1, Col2, Col3, Col4, Col5 ) 
         --VALUES ( 'rdtfnc_UCCInfo' , GetDate() , @cValidateTable , @cStorerKey, @cFacility, @cValidateField, @cRefNo ) 
         
           
         SET @cExecStatements  = N'SELECT @nPassValidation = COUNT( 1) ' + char(13) +     
                                  ' FROM ' + @cValidateTable  + ' (NOLOCK) ' + Char(13) +     
                                  ' WHERE StorerKey = ''' + @cStorerKey  + '''' + char(13) +     
                                  ' AND Facility = ''' + @cFacility + '''' + Char(13) +     
                                  ' AND ' + @cValidateField + ' = ''' + @cRefNo + ''''  
    
         SET @cExecArguments = N'@nPassValidation     INT OUTPUT  '     
    
         EXEC sp_ExecuteSql @cExecStatements, @cExecArguments     
                               ,@nPassValidation OUTPUT    
                                 
           
         IF ISNULL(@nPassValidation, 0 )  = 0   
         BEGIN   
            SET @cRefNo = ''  
            SET @cUCCNo = ''
            SET @nErrNo = 98154  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidRefNo  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END  
         
         EXEC rdt.rdtSetFocusField @nMobile, 2  
           
      END  
        
        
      IF @cUCCNo = ''  
      BEGIN  
         SET @cUCCNo = ''  
         SET @nErrNo = 98151  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCReq  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_1_Fail  
      END  
        
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)   
                      WHERE UCCNo = @cUCCNo  
                      AND StorerKey = @cStorerKey )   
      BEGIN  
         SET @cUCCNo = ''  
         SET @nErrNo = 98152  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_1_Fail  
      END  
      
      SELECT @cDisplaySQLStatement = Notes  
      FROM dbo.CodeLkup WITH (NOLOCK)   
      WHERE ListName = 'UCCINFO'  
      AND Code = '2'  
      AND StorerKey = @cStorerKey  
        
      IF CHARINDEX( 'UPDATE', @cDisplaySQLStatement ) > 0   
      BEGIN   
         SET @cUCCNo = ''  
         SET @nErrNo = 98155  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSetup  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_1_Fail  
      END  
      
      IF CHARINDEX( 'INSERT', @cDisplaySQLStatement ) > 0   
      BEGIN   
         SET @cUCCNo = ''  
         SET @nErrNo = 98156  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSetup  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_1_Fail  
      END  
      
        
      SET @cExecStatements  = @cDisplaySQLStatement  
    
      SET @cExecArguments = N'@cUCCNo  CHAR(20) , ' +     
                             '@cRefNo  NVARCHAR(20) , ' +     
                             '@cParm1  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm2  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm3  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm4  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm5  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm6  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm7  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm8  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm9  NVARCHAR(20) OUTPUT, ' +     
                             '@cParm10  NVARCHAR(20) OUTPUT '      
                               
    
      EXEC sp_ExecuteSql @cExecStatements, @cExecArguments    
                               , @cUCCNo   
                               , @cRefNo    
                               , @cParm1 OUTPUT  
                               , @cParm2 OUTPUT  
                               , @cParm3 OUTPUT  
                               , @cParm4 OUTPUT  
                               , @cParm5 OUTPUT  
                               , @cParm6 OUTPUT  
                               , @cParm7 OUTPUT  
                               , @cParm8 OUTPUT  
                               , @cParm9 OUTPUT  
                               , @cParm10 OUTPUT  
        
        
      -- Prepare next screen var  
      SET @cOutField02 = ''  
      SET @cOutField01 = @cRefNo  
      SET @cOutField03 = @cParm1  
      SET @cOutField04 = @cParm2  
      SET @cOutField05 = @cParm3  
      SET @cOutField06 = @cParm4  
      SET @cOutField07 = @cParm5  
      SET @cOutField08 = @cParm6  
      SET @cOutField09 = @cParm7  
      SET @cOutField10 = @cParm8  
      SET @cOutField11 = @cParm9  
      SET @cOutField12 = @cParm10  
        
--      IF ISNULL(@cValidate,'') = '1'  
--      BEGIN
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--      END
--      ELSE
--      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2
--      END
        
        
       
   END  
  
   IF @nInputKey = 0 --ESC  
   BEGIN  
      --go to main menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  
  
  
   Step_1_Fail:  
   BEGIN  
      SET @cOutField01 = @cRefNo  
      SET @cOutField02 = @cUCCNo  
      
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ''  
      SET @cOutField12 = ''  
      
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
  
      V_String1 = @cRefNo,  
  
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15  
  
   WHERE Mobile = @nMobile  
END  


GO
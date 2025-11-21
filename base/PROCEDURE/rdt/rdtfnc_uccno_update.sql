SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_UCCNo_Update                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: serialNo Update                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2023-02-20   1.0  yeekung    WMS-21745 Created                      */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_UCCNo_Update] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @curData        CURSOR

DECLARE @cSQL           NVARCHAR( MAX)
DECLARE @cSQLParam      NVARCHAR( MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cUCCNo           NVARCHAR( 30),
   @cCode               NVARCHAR( 20),
   @cLabel              NVARCHAR( 20),

   @cLblData1           NVARCHAR( 20),
   @cLblData2           NVARCHAR( 20),
   @cLblData3           NVARCHAR( 20),
   @cLblData4           NVARCHAR( 20),
   @cLblData5           NVARCHAR( 20),

   @cData1              NVARCHAR( 20),
   @cData2              NVARCHAR( 20),
   @cData3              NVARCHAR( 20),
   @cData4              NVARCHAR( 20),
   @cData5              NVARCHAR( 20),
   @cData               NVARCHAR( 20),

   @cActionType         NVARCHAR(10),   -- (ChewKP01)

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
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,

   @cUCCNo         = V_Max,

   @cLblData1     = V_String1,
   @cLblData2     = V_String2,
   @cLblData3     = V_String3,
   @cLblData4     = V_String4, 
   @cLblData5     = V_String5,

   @cData1        = V_String6,
   @cData2        = V_String7,
   @cData3        = V_String8,
   @cData4        = V_String9,
   @cData5        = V_String10,  

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile


IF @nFunc = 1027	  
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 1019
   IF @nStep = 1  GOTO Step_UCCNo    -- Scn = 6180. UCC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 652
********************************************************************************/
Step_Start:
BEGIN
   
   SET @cLblData1   = ''
   SET @cLblData2   = ''
   SET @cLblData3   = ''
   SET @cLblData4   = ''
   SET @cLblData5   = ''


   SET @cFieldAttr03 = 'O'
   SET @cFieldAttr05 = 'O'
   SET @cFieldAttr07 = 'O'
   SET @cFieldAttr09 = 'O'
   SET @cFieldAttr11 = 'O'

   IF NOT EXISTS (SELECT 1
                  FROM dbo.CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'UCCNoUpd'
                     AND Storerkey = @cStorerKey
                     AND Code2 = @nFunc)
   BEGIN
      SET @nErrNo = 196751        
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLblNotExists       
      GOTO QUIT        
   END

   SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, Notes
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'UCCNoUpd'
      AND Storerkey = @cStorerKey
      AND Code2 = @nFunc
   ORDER BY Code
   OPEN @curData
   FETCH NEXT FROM @curData INTO @cCode, @cLabel
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF ISNULL( @cLabel, '') <> ''
      BEGIN
         IF @cCode = '1' SELECT @cOutField02 = @cLabel,@cLblData1= @cLabel ,@cFieldAttr03 = '' ELSE
         IF @cCode = '2' SELECT @cOutField04 = @cLabel,@cLblData1= @cLabel ,@cFieldAttr05 = '' ELSE
         IF @cCode = '3' SELECT @cOutField06 = @cLabel,@cLblData1= @cLabel ,@cFieldAttr07 = '' ELSE
         IF @cCode = '4' SELECT @cOutField08 = @cLabel,@cLblData1= @cLabel ,@cFieldAttr09 = '' ELSE
         IF @cCode = '5' SELECT @cOutField10 = @cLabel,@cLblData1= @cLabel ,@cFieldAttr11 = ''
      END

      FETCH NEXT FROM @curData INTO @cCode, @cLabel
   END

   EXEC rdt.rdtSetFocusField @nMobile, 1


   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '1', -- Sign In Function
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = '',
      @nStep         = @nStep

   -- Go to Label screen
   SET @nScn = 6210
   SET @nStep = 1
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit

/***********************************************************************************        
Scn = 5450. SerialNo screen        
   SerialNo:
   (field01)    
   (field02)    
   (field03)    
   (field04)    
   (field05)    
   (field06)    
   (field07)    
   (field08)    
   (field09)    
   (field10)    
   (field11)   
***********************************************************************************/        
Step_UCCNo:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
    
      SET @cUCCNo = @cInField01
      SET @cData1    = @cInField03
      SET @cData2    = @cInField05
      SET @cData3    = @cInField07
      SET @cData4    = @cInField09
      SET @cData5    = @cInField11
    
      IF ISNULL(@cUCCNo,'')=''    
      BEGIN    
         SET @nErrNo = 196752        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedUCCNo     
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step1_UCCNO_Fail        
      END  
      

      IF NOT EXISTS (SELECT 1 FROM UCC (NOLOCK)
                     WHERE storerkey=@cStorerkey
                        AND uccno=@cUCCNo
                        AND status='1')
      BEGIN    
         SET @nErrNo = 196753        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCCNo       
         GOTO Step1_UCCNO_Fail        
      END 
      
      IF @cLblData1<>'' AND ISNULL(@cData1,'')=''
      BEGIN    
         SET @nErrNo = 196754        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value 
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step1_Data_Fail        
      END 

            
      IF @cLblData2<>'' AND ISNULL(@cData2,'')=''
      BEGIN    
         SET @nErrNo = 196755        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value 
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Step1_Data_Fail        
      END 

      IF @cLblData3<>'' AND ISNULL(@cData3,'')=''
      BEGIN    
         SET @nErrNo = 196756        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value 
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step1_Data_Fail        
      END 

      IF @cLblData4<>'' AND ISNULL(@cData4,'')=''
      BEGIN    
         SET @nErrNo = 196757        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value
         EXEC rdt.rdtSetFocusField @nMobile, 9
         GOTO Step1_Data_Fail        
      END 

      IF @cLblData5<>'' AND ISNULL(@cData5,'')=''
      BEGIN    
         SET @nErrNo = 196758        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value 
         EXEC rdt.rdtSetFocusField @nMobile, 11
         GOTO Step1_Data_Fail        
      END 

      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_UCCNo_Update

      SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Code, Notes
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'UCCNoUpd'
         AND Storerkey = @cStorerKey
         AND Code2 = @nFunc
      ORDER BY Code
      OPEN @curData
      FETCH NEXT FROM @curData INTO @cCode, @cLabel
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL( @cLabel, '') <> ''
         BEGIN
            -- Check column valid
            IF NOT EXISTS( SELECT 1
               FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'UCC'
                  AND COLUMN_NAME = @cLabel
                  AND DATA_TYPE = 'nvarchar')
            BEGIN
               SET @nErrNo = 154651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
               ROLLBACK TRAN 
               GOTO Quit
            END

            IF @cCode = '1' SELECT @cData = @cData1
            IF @cCode = '2' SELECT @cData = @cData2
            IF @cCode = '3' SELECT @cData = @cData3
            IF @cCode = '4' SELECT @cData = @cData4
            IF @cCode = '5' SELECT @cData = @cData5

            SET @cSQL =
               'UPDATE UCC WITH (ROWLOCK) '+
               'SET ' + @cLabel + ' = @cData ' +
               'WHERE storerkey=@cStorerkey' +
               '  AND UCCNo=@cUCCNo' +
               '  AND status=''1''' 

            SET @cSQLParam =
               ' @cStorerKey     NVARCHAR(15), ' +
               ' @cUCCNo      NVARCHAR(30), ' +
               ' @cData          NVARCHAR(20) ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cStorerKey,
               @cUCCNo,
               @cData 

            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               ROLLBACK TRAN rdtfnc_UCCNo_Update
               GOTO Quit 
            END
         END

         FETCH NEXT FROM @curData INTO @cCode, @cLabel
      END

      COMMIT TRAN rdtfnc_UCCNo_Update

      SET @cData1    = ''
      SET @cData2    = ''
      SET @cData3    = ''
      SET @cData4    = ''
      SET @cData5    = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      EXEC RDT.rdt_STD_EventLog        
         @cActionType   = '9', -- Sign Out Function        
         @nMobileNo     = @nMobile,        
         @nFunctionID   = @nFunc,        
         @cFacility     = @cFacility,        
         @cStorerKey    = @cStorerKey,        
         @nStep         = @nStep        
        
      -- Back to menu        
      SET @nFunc = @nMenu        
      SET @nScn  = @nMenu        
      SET @nStep = 0        
   END      
   GOTO Quit      
    
   Step1_UCCNO_Fail:    
   BEGIN    
      SET @cInField01=''    
      SET @cUCCNo='' 
      GOTO QUIT
   END   
   
   Step1_Data_Fail:
   BEGIN    
      SET @cOutField01= @cUCCNo   
      GOTO QUIT
   END   
END        
GOTO Quit         

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      V_Max          = @cUCCNo,

      V_String1      = @cLblData1, 
      V_String2      = @cLblData2, 
      V_String3      = @cLblData3, 
      V_String4      = @cLblData4, 
      V_String5      = @cLblData5, 

      V_String6      = @cData1,    
      V_String7      = @cData2,    
      V_String8      = @cData3,    
      V_String9      = @cData4,    
      V_String10     = @cData5,    

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
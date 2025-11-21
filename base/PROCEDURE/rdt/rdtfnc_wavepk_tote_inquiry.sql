SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_WavePK_tote_Inquiry                               */
/*                                                                           */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2020-07-30 1.0  Chermaine WMS-14247 Created                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_WavePK_tote_Inquiry](
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

   @cToteNo             NVARCHAR(10),
   @cStoreNo            NVARCHAR(10),
   @cStatus             NVARCHAR(10),
   @cWavePK             NVARCHAR(20),
   @cWavePKGet          NVARCHAR(20),

   @nPage               INT,
   @nBalance            INT,

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   
   @cOutValue01         NVARCHAR( 20),
   @cOutValue02         NVARCHAR( 20),
   @cOutValue03         NVARCHAR( 20),
   @cOutValue04         NVARCHAR( 20),
   @cOutValue05         NVARCHAR( 20),
   @cOutValue06         NVARCHAR( 20),


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
   
   @nPage            = V_Integer1,
   @nBalance         = V_Integer2,

   @cToteNo          = V_String1,
   @cWavePK          = V_String2,
   @cWavePKGet       = V_String3,
      
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
IF @nFunc = 1844
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1844
   IF @nStep = 1 GOTO Step_1   -- Scn = 5790   WavePK,Tote#
   IF @nStep = 2 GOTO Step_2   -- Scn = 5791   Result WakePK
   IF @nStep = 3 GOTO Step_3   -- Scn = 5792   Result Tote#
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1844)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 5790
   SET @nStep = 1
   SET @nPage = 1

   
   -- initialise all variable
   SET @cToteNo = ''
   SET @cWavePK = ''
   

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 5790
   WAVEPK #    (Field01, input)
   TOTE ID #   (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWavePK = @cInField01
      SET @cToteNo = @cInField02

      --When Tote# is blank
      IF @cWavePK = '' AND @cToteNo = ''
      BEGIN
         SET @nErrNo = 156051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave#/Tote Req
         GOTO Step_1_Fail  
         GOTO Quit   
      END 
      
      IF @cWavePK <> ''
      BEGIN
      	IF NOT EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND (WaveKey + CaseID) = @cWavePK)
      	BEGIN
      		SET @nErrNo = 156052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WavePKNotFound
            GOTO Step_1_Fail  
            GOTO Quit  
      	END
      	
         IF EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND (WaveKey + CaseID) = @cWavePK AND ISNULL(dropID,'') = '')  --hv blank dropID
         BEGIN
         	IF EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND (WaveKey + CaseID) = @cWavePK AND ISNULL(dropID,'') <> '') --hv partial blank
         	BEGIN
         		SET @nErrNo = 156053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PartialAssign
               GOTO Step_1_Fail  
               GOTO Quit 
         	END
         	
         	SET @nErrNo = 156054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote#NotAssign
            GOTO Step_1_Fail  
            GOTO Quit    
         END
         
         -- Get task
         EXEC rdt.rdt_WavePK_Tote_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'WavePK'
            ,@nPage
            ,@cWavePK
            ,@cOutValue01  OUTPUT
            ,@cOutValue02  OUTPUT
            ,@cOutValue03  OUTPUT
            ,@cOutValue04  OUTPUT
            ,@cOutValue05  OUTPUT
            ,@cOutValue06  OUTPUT
            ,@nBalance     OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cWavePK
         SET @cOutField02 = @cOutValue01
         SET @cOutField03 = @cOutValue02
         SET @cOutField04 = @cOutValue03
         SET @cOutField05 = @cOutValue04
         SET @cOutField06 = @cOutValue05
         SET @cOutField07 = @cOutValue06
         
         IF @nBalance > 0 
         BEGIN
         	SET @cOutField08 = 'ENTER TO NEXT PAGE'
         END  
         ELSE
         BEGIN
         	SET @cOutField08 = 'END'      
         	SET @nPage = 1      
         END        
         -- Go to wavePK result screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      IF @cWavePK = '' AND @cToteNo <> ''
      BEGIN
      	IF NOT EXISTS (SELECT 1 
                           FROM Pickdetail PD (NOLOCK)  
                           JOIN ORDERS O (NOLOCK) ON (o.orderkey = PD.OrderKey AND o.StorerKey = PD.Storerkey)
                           WHERE PD.storerKey = @cStorerKey 
                           AND PD.dropID  =@cToteNo
                           AND PD.status <> '9' 
                           AND O.SOStatus <> '5')
      	BEGIN
      		SET @nErrNo = 156055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoOrdersAssign
            GOTO Step_1_Fail  
            GOTO Quit  
      	END
      	
      	SELECT @cWavePKGet = waveKey + caseID FROM pickDetail (NOLOCK) WHERE dropID = @cToteNo
      	--INSERT INTO traceInfo (TraceName,col1,col2)
      	--VALUES('ccInq1',@cWavePKGet,@cToteNo)
      	         
         -- Get task
         EXEC rdt.rdt_WavePK_Tote_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'ToteID'
            ,@nPage
            ,@cToteNo
            ,@cOutValue01  OUTPUT
            ,@cOutValue02  OUTPUT
            ,@cOutValue03  OUTPUT
            ,@cOutValue04  OUTPUT
            ,@cOutValue05  OUTPUT
            ,@cOutValue06  OUTPUT
            ,@nBalance     OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = @cWavePKGet
         SET @cOutField03 = @cOutValue01
         SET @cOutField04 = @cOutValue02
         SET @cOutField05 = @cOutValue03
         SET @cOutField06 = @cOutValue04
         SET @cOutField07 = @cOutValue05
         SET @cOutField08 = @cOutValue06
         
         IF @nBalance > 0 
         BEGIN
         	SET @cOutField09 = 'ENTER TO NEXT PAGE'
         END  
         ELSE
         BEGIN
         	SET @cOutField09 = 'END'   
         	SET @nPage = 1         
         END        
         -- Go to wavePK result screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2      
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- initialise all variable
      SET @cToteNo = ''
      SET @cWavePK = ''

      -- Prep next screen var   
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' 
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cWavePK = ''
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 5791) 
   WavePK:  (Field01)
   AssignToteID:  (Field02)-(Field07)
   Text : (Field08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER / ESC
   BEGIN
      --IF @nBalance > 0
      --BEGIN
      	SET @nPage = @nPage + 1
      	IF @cWavePK <> ''
      	BEGIN
      		-- Get task
            EXEC rdt.rdt_WavePK_Tote_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'WavePK'
               ,@nPage
               ,@cWavePK
               ,@cOutValue01  OUTPUT
               ,@cOutValue02  OUTPUT
               ,@cOutValue03  OUTPUT
               ,@cOutValue04  OUTPUT
               ,@cOutValue05  OUTPUT
               ,@cOutValue06  OUTPUT
               ,@nBalance     OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Prepare next screen var
            SET @cOutField01 = @cWavePK
            SET @cOutField02 = @cOutValue01
            SET @cOutField03 = @cOutValue02
            SET @cOutField04 = @cOutValue03
            SET @cOutField05 = @cOutValue04
            SET @cOutField06 = @cOutValue05
            SET @cOutField07 = @cOutValue06
         
            IF @nBalance > 0 
            BEGIN
         	   SET @cOutField08 = 'ENTER TO NEXT PAGE'
            END  
            ELSE
            BEGIN
         	   SET @cOutField08 = 'END'     
         	   SET @nPage = 0     
            END        
      	END
      --END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back wavePK/ToteID scn
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      -- initialise all variable
      SET @cToteNo = ''
      SET @cWavePK = ''

      -- Prep next screen var   
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' 
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 3. (screen = 5792) 
   ToteNo: (Field01)
   WavePK: (Field02)
   SKU,QTY,ALSKU:  (Field03)-(Field08)
   Text : (Field09)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER / ESC
   BEGIN
      --IF @nBalance > 0
      --BEGIN
      	SET @nPage = @nPage + 1
     	
      	IF @cWavePK = '' AND @cToteNo <> ''
      	BEGIN
      		-- Get task
            EXEC rdt.rdt_WavePK_Tote_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'ToteID'
               ,@nPage
               ,@cToteNo
               ,@cOutValue01  OUTPUT
               ,@cOutValue02  OUTPUT
               ,@cOutValue03  OUTPUT
               ,@cOutValue04  OUTPUT
               ,@cOutValue05  OUTPUT
               ,@cOutValue06  OUTPUT
               ,@nBalance     OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Prepare next screen var
            SET @cOutField01 = @cToteNo
            SET @cOutField02 = @cWavePKGet
            SET @cOutField03 = @cOutValue01
            SET @cOutField04 = @cOutValue02
            SET @cOutField05 = @cOutValue03
            SET @cOutField06 = @cOutValue04
            SET @cOutField07 = @cOutValue05
            SET @cOutField08 = @cOutValue06
         
            IF @nBalance > 0 
            BEGIN
         	   SET @cOutField09 = 'ENTER TO NEXT PAGE'
            END  
            ELSE
            BEGIN
         	   SET @cOutField09 = 'END'     
         	   SET @nPage = 0       
            END        
      	END
      --END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back wavePK/ToteID scn
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      -- initialise all variable
      SET @cToteNo = ''
      SET @cWavePK = ''

      -- Prep next screen var   
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = '' 
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
       
       V_Integer1    = @nPage,
       V_Integer2    = @nBalance,

       V_String1     = @cToteNo,
       V_String2     = @cWavePK,    
       V_String3     = @cWavePKGet,

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
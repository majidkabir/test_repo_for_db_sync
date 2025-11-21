SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Tote_ConveyerMove                                 */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Allow User to Scan the Tote and Send Instruction to WCS to move  */
/*          to specified station.                                            */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-08-27 1.0  Shong    Created                                          */
/* 2010-11-10 1.1  James    SOS195384 - Cater for multi station move(james01)*/    
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Tote_ConveyerMove](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @bSuccess           INT
        
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
   @cCaseID             NVARCHAR(18),                
   @cStation            NVARCHAR(10),
   @cWCSKey             NVARCHAR(10),
   @cFinalLoc           NVARCHAR(10),
   @nStationCnt         INT, 
   @cStation1           NVARCHAR(10), 
   @cStation2           NVARCHAR(10), 
   @cStation3           NVARCHAR(10), 
   @cStation4           NVARCHAR(10), 
   @cStation5           NVARCHAR(10), 
   @cStation6           NVARCHAR(10), 
   @cStation7           NVARCHAR(10), 
   @cWCSStation         NVARCHAR(10), 
   @cOption             NVARCHAR(1), 
   @cInit_Final_Zone    NVARCHAR(10), 
   @cFinalWCSZone       NVARCHAR(10), 
   @nCount              INT,

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

   @cCaseID          = V_ID,
   @cStation         = V_String1,
   @cToteNo          = V_String2,
   @nStationCnt      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @cStation1        = V_String4,
   @cStation2        = V_String5,
   @cStation3        = V_String6,
   @cStation4        = V_String7,
   @cStation5        = V_String8,
   @cStation6        = V_String9,
   @cStation7        = V_String10,
         
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
IF @nFunc = 1777
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1777
   IF @nStep = 1 GOTO Step_1   -- Scn = 2530  Tote No
   IF @nStep = 2 GOTO Step_2   -- Scn = 2531  Station
   IF @nStep = 3 GOTO Step_3   -- Scn = 2532  Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1777)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2530
   SET @nStep = 1

   -- initialise all variable
   SET @cToteNo = ''
   SET @cCaseID = ''
   SET @cStation = ''

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
   SET @cOutField10 = '' 
   SET @cOutField11 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2530
   TOTE NO (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToteNo = SUBSTRING(@cInField01, 1, 8)
      SET @cCaseID = SUBSTRING(@cInField02, 1, 8)

      IF ISNULL(@cCaseID, '') = '' AND ISNULL(@cToteNo, '') = ''         
      BEGIN                
         SET @nErrNo = 71116                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CASE/TOTE req                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END                
                
      IF ISNULL(@cCaseID, '') <> '' AND ISNULL(@cToteNo, '') <> ''                
      BEGIN             
         SET @nErrNo = 71117                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CASE/TOTE ONLY                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END                

      -- TOTE validation
      IF ISNULL(@cCaseID, '') = '' AND ISNULL(@cToteNo, '') <> ''   
      BEGIN
         IF ISNUMERIC(@cToteNo) = 0            
         BEGIN            
            SET @nErrNo = 71118                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTENO                
            EXEC rdt.rdtSetFocusField @nMobile, 1                
            GOTO Step_1_Fail                
         END            

         IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)            
                        WHERE StorerKey = @cStorerKey            
                           AND DropID = @cToteNo)            
         BEGIN            
            SET @nErrNo = 71119                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID TOTENO                
            EXEC rdt.rdtSetFocusField @nMobile, 1                
            GOTO Step_1_Fail                
         END          
      END

      -- CASE validation
      IF ISNULL(@cCaseID, '') <> '' AND ISNULL(@cToteNo, '') = ''   
      BEGIN
         IF ISNUMERIC(@cCaseID) = 0            
         BEGIN            
            SET @nErrNo = 71120                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID CASEID                
            EXEC rdt.rdtSetFocusField @nMobile, 2                
            GOTO Step_1_Fail                
         END            
            
         IF NOT EXISTS (SELECT 1 FROM TaskDetail TD WITH (NOLOCK)             
                        JOIN dbo.UCC UCC WITH (NOLOCK) ON TD.TaskDetailKey = UCC.SourceKey            
                        WHERE TD.StorerKey = @cStorerKey            
                           AND TD.Status NOT IN ('X')  -- SHONGxx           
                           AND UCC.UCCNo = @cCaseID)            
         BEGIN            
            SET @nErrNo = 71121                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID CASEID                
            EXEC rdt.rdtSetFocusField @nMobile, 2                
            GOTO Step_1_Fail                
         END                  
      END

      -- Prev next screen
      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @cStation = ''
      SET @cStation1 = ''
      SET @cStation2 = ''
      SET @cStation3 = ''
      SET @cStation4 = ''
      SET @cStation5 = ''
      SET @cStation6 = ''
      SET @cStation7 = ''
      SET @nStationCnt = 0

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
      SET @cCaseID = ''
      SET @cStation = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cCaseID = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 2531
   Tote    (field01)
   Station (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cStation = @cInField03

      IF ISNULL(RTRIM(@cStation), '') = ''
      BEGIN
         SET @nErrNo = 71122
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Station Req
         GOTO Step_2_Fail  
      END
      
      IF NOT EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK) WHERE c.LISTNAME = 'WCSSTATION' AND C.Code = @cStation)
      BEGIN
         SET @nErrNo = 71123
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Station
         GOTO Step_2_Fail  
      END

      SET @nStationCnt = @nStationCnt + 1

      IF @nStationCnt > 7
      BEGIN
         SET @nErrNo = 71124
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CANNOT >7 STAT
         GOTO Step_2_Fail  
      END

      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = ''        
      IF @nStationCnt = 1
      BEGIN
         SET @cStation1 = @cStation
         SET @cOutField04 = @cStation
      END
      ELSE
      IF @nStationCnt = 2
      BEGIN
         SET @cStation2 = @cStation
         SET @cOutField05 = @cStation
      END
      ELSE
      IF @nStationCnt = 3
      BEGIN
         SET @cStation3 = @cStation
         SET @cOutField06 = @cStation
      END
      ELSE
      IF @nStationCnt = 4
      BEGIN
         SET @cStation4 = @cStation
         SET @cOutField07 = @cStation
      END
      ELSE
      IF @nStationCnt = 5
      BEGIN
         SET @cStation5 = @cStation
         SET @cOutField08 = @cStation
      END
      ELSE
      IF @nStationCnt = 6
      BEGIN
         SET @cStation6 = @cStation
         SET @cOutField09 = @cStation
      END
      ELSE
      IF @nStationCnt = 7
      BEGIN
         SET @cStation7 = @cStation
         SET @cOutField10 = @cStation
      END

      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = '' 
      SET @cOption = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END  
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = ''        

      SET @cStation = ''
   END
   GOTO Quit
   
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2532
   Option (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cOption = @cInField01

      -- Check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 71125
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Opt required 
         GOTO Step_3_Fail      
      END      

      -- Check if option is valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 71126
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv Option 
         GOTO Step_3_Fail      
      END      

      IF @cOption = '1'
      BEGIN
         BEGIN TRAN

         -- Cancel all route be
         SET @cInit_Final_Zone = ''    
         SET @cFinalWCSZone = ''    

         SELECT TOP 1 
            @cFinalWCSZone = Final_Zone,    
            @cInit_Final_Zone = Initial_Final_Zone    
         FROM dbo.WCSRouting WITH (NOLOCK)    
         WHERE ToteNo = @cToteNo    
         AND ActionFlag = 'I'    
         ORDER BY WCSKey Desc    

         SET @cWCSKey = ''
         EXECUTE nspg_GetKey         
         'WCSKey',         
         10,         
         @cWCSKey   OUTPUT,         
         @bsuccess  OUTPUT,         
         @nErrNo    OUTPUT,         
         @cErrMsg   OUTPUT          
               
         IF @nErrNo<>0        
         BEGIN        
            SET @nErrNo = 71127
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
            GOTO Step_3_Fail  
         END          
               
         INSERT INTO WCSRouting        
         (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)        
         VALUES        
         ( @cWCSKey, @cToteNo, ISNULL(@cInit_Final_Zone,''), ISNULL(@cFinalWCSZone,''), 'D', @cStorerKey, @cFacility, '', 'ToteMove') 
               
         SELECT @nErrNo = @@ERROR          

         IF @nErrNo<>0        
         BEGIN        
            SET @nErrNo = 71128
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFail
            GOTO Step_3_Fail  
         END         
               
         -- Update WCSRouting.Status = '5' When Delete          
         UPDATE WCSRouting WITH (ROWLOCK)        
         SET    STATUS = '5'        
         WHERE  ToteNo = @cToteNo          

         SELECT @nErrNo = @@ERROR          
         IF @nErrNo<>0        
         BEGIN        
            SET @nErrNo = 71129
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRouteFail
            GOTO Step_3_Fail     
         END         

         EXEC dbo.isp_WMS2WCSRouting  
              @cWCSKey,  
              @cStorerKey,  
              @bSuccess OUTPUT,  
              @nErrNo  OUTPUT,   
              @cErrMsg OUTPUT  
        
         IF @nErrNo <> 0   
         BEGIN  
            SET @nErrNo = 71130
            SET @cErrMsg = rdt.rdtgetmessage( 71125, @cLangCode, 'DSP') --CrtWCSRECFail
            GOTO Step_3_Fail  
         END

         -- Insert Routing Record Here
         SET @cFinalLoc = ''
         SELECT @cFinalLoc = SHORT 
         FROM   Codelkup WITH (NOLOCK)
         WHERE  LISTNAME = 'WCSSTATION'
         AND    Code = CASE WHEN @nStationCnt = 1 THEN @cStation1 
                            WHEN @nStationCnt = 2 THEN @cStation2 
                            WHEN @nStationCnt = 3 THEN @cStation3 
                            WHEN @nStationCnt = 4 THEN @cStation4 
                            WHEN @nStationCnt = 5 THEN @cStation5 
                            WHEN @nStationCnt = 6 THEN @cStation6 
                            WHEN @nStationCnt = 7 THEN @cStation7 
                         END

         IF ISNULL(RTRIM(@cFinalLoc),'') = ''  
         BEGIN
            SET @nErrNo = 71131
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Station
            GOTO Step_3_Fail  
         END
         
         EXECUTE nspg_GetKey  
         'WCSKey',  
         10,     
         @cWCSKey      OUTPUT,  
         @bSuccess     OUTPUT,  
         @nErrNo       OUTPUT,  
         @cErrMsg      OUTPUT  

         IF @nErrNo <> 0   
         BEGIN
            SET @nErrNo = 71132
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
            GOTO Step_3_Fail  
         END

         IF ISNULL(@cToteNo, '') <> ''
            INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)  
            VALUES (@cWCSKey, @cToteNo, '', @cFinalLoc, 'I',  @cStorerKey, @cFacility, '', 'ToteMove') -- Insert  
         ELSE
            INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)  
            VALUES (@cWCSKey, @cCaseID, '', @cFinalLoc, 'I',  @cStorerKey, @cFacility, '', 'ToteMove') -- Insert  

         SELECT @nErrNo = @@ERROR  
         IF @nErrNo <> 0   
         BEGIN
            SET @nErrNo = 71133
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFail
            GOTO Step_3_Fail  
         END

         SET @nCount = 1

         WHILE @nStationCnt > 0
         BEGIN
            SET @cWCSStation = ''
            SELECT @cWCSStation = SHORT 
            FROM   Codelkup WITH (NOLOCK)
            WHERE  LISTNAME = 'WCSSTATION'
            AND    Code = CASE WHEN @nCount = 1 THEN @cStation1 
                               WHEN @nCount = 2 THEN @cStation2 
                               WHEN @nCount = 3 THEN @cStation3 
                               WHEN @nCount = 4 THEN @cStation4 
                               WHEN @nCount = 5 THEN @cStation5 
                               WHEN @nCount = 6 THEN @cStation6 
                               WHEN @nCount = 7 THEN @cStation7 
                            END

            IF ISNULL(@cToteNo, '') <> ''
               INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)  
               VALUES (@cWCSKey, @cToteNo, @cWCSStation, 'I') -- Insert  
            ELSE
               INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)  
               VALUES (@cWCSKey, @cCaseID, @cWCSStation, 'I') -- Insert  

            SELECT @nErrNo = @@ERROR  
            IF @nErrNo <> 0   
            BEGIN
               SET @nErrNo = 71134
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFaild
               GOTO Step_3_Fail  
            END

            SET @nCount = @nCount + 1
            SET @nStationCnt = @nStationCnt - 1
         END
                  
         IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @cWCSKey)  
         BEGIN  
            DELETE FROM WCSRouting   
            WHERE WCSKey = @cWCSKey  
         END  
         ELSE  
         BEGIN  
            EXEC dbo.isp_WMS2WCSRouting  
                 @cWCSKey,  
                 @cStorerKey,  
                 @bSuccess OUTPUT,  
                 @nErrNo  OUTPUT,   
                 @cErrMsg OUTPUT  
           
            IF @nErrNo <> 0   
            BEGIN  
               SET @nErrNo = 71135
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtWCSRECFail
               GOTO Step_3_Fail  
            END
         END  
         -- Insert Routing Record End

         COMMIT TRAN

         -- initialise all variable
         SET @cToteNo = ''
         SET @cCaseID = ''

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
         SET @cOutField10 = '' 
         SET @cOutField11 = '' 

         EXEC rdt.rdtSetFocusField @nMobile, 1                

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END

      IF @cOption = '9'
      BEGIN
         -- initialise all variable
         SET @cToteNo = ''
         SET @cCaseID = ''

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
         SET @cOutField10 = '' 
         SET @cOutField11 = '' 

         EXEC rdt.rdtSetFocusField @nMobile, 1                

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN 'TOTE NO:' ELSE 'CASE ID:' END
      SET @cOutField02 = CASE WHEN ISNULL(@cToteNo, '') <> '' THEN @cToteNo ELSE @cCaseID END 
      SET @cOutField03 = ''        

      SET @cStation = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOption = ''
      ROLLBACK TRAN 
   END
   GOTO Quit
END
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg        = @cErrMsg, 
      Func          = @nFunc,
      Step          = @nStep,            
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility, 
      Printer       = @cPrinter,    
      UserName      = @cUserName,

      V_ID          = @cCaseID,       
      V_String1     = @cStation,  
      V_String2     = @cToteNo,   
      V_String3     = @nStationCnt,
      V_String4     = @cStation1,
      V_String5     = @cStation2,
      V_String6     = @cStation3,
      V_String7     = @cStation4,
      V_String8     = @cStation5,
      V_String9     = @cStation6,
      V_String10    = @cStation7,

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
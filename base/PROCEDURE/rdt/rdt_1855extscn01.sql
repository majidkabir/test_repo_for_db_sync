SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***********************************************************************************/  
/* Store procedure: rdt_1855ExtScn01                                               */  
/*                                                                                 */  
/* Purpose: For US Levis                                                           */
/*                                                                                 */
/* Modifications log:                                                              */  
/*                                                                                 */  
/* Date       Rev    Author     Purposes                                           */  
/* 2024-07-31 1.0    JACKC      FCR-652. Created                                   */
/* 2024-09-18 1.2    JACKC      FCR-652. Per support request                       */
/* 2024-09-13 1.3    JACKC      FCR-856. Lock Tasks on carton level                */ 
/* 2024-12-13 1.4.0  NLT013     FCR-1755. Change the logic for Automaticaion       */ 
/* 2024-12-13 1.4.1  NLT013     FCR-1755. Empty REQUIRED QTY for normal Pick       */ 
/* 2025-01-15 1.4.2  NLT013     FCR-1755 Remove duplicate scanned tote             */
/***********************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1855ExtScn01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep INT,           
   @nScn  INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData   VariableTable READONLY,

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 2. Prepare output fields, Step = 99 is a new screen
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      --rdtmobrec
      @cUserName              NVARCHAR( 18),
      @nMenu                  INT,
      @bDebugFlag             BINARY = 0,
      @nMOBRECStep            INT,
      @nMOBRECScn             INT,
      @cExtendedScnSP         NVARCHAR( 20),
      
      --config variable
      @nRowCount              INT,
      @cExtendedUpdateSP      NVARCHAR( 20),
      @cExtendedValidateSP    NVARCHAR( 20),
      @cExtendedInfoSP        NVARCHAR( 20),
      @cSQL                   NVARCHAR(MAX),         
      @cSQLParam              NVARCHAR(MAX),

      -- 1855 Original Step1 variables
      @cMethod                         NVARCHAR( 1),
      @cPickZone                       NVARCHAR( 10),
      @cCartID                         NVARCHAR( 10),
      @cResult01                       NVARCHAR( 20),            
      @cResult02                       NVARCHAR( 20),            
      @cResult03                       NVARCHAR( 20),            
      @cResult04                       NVARCHAR( 20),            
      @cResult05                       NVARCHAR( 20),
      @cContinuePickOnAssignedCart     NVARCHAR( 1),
      @nStep_ContTask                  INT,  
      @nScn_ContTask                   INT,
      @cCartonID                       NVARCHAR( 20),
      @cCartPickMethod                 NVARCHAR( 40),
      @nCartLimit                      INT,
      @cPickNoMixWave                  NVARCHAR( 1),
      @cPickWaveKey                    NVARCHAR( 10),
      @nTranCount                      INT,
      @cGroupKey                       NVARCHAR( 10),
      @cWaveKey                        NVARCHAR( 10),
      @cLockTaskKey                    NVARCHAR( 10),
      @nNextPage                       INT,
      @cSKU                            NVARCHAR( 20),
      @cFromLoc                        NVARCHAR( 10),
      @nQTY                            INT=0,
      @cTaskDetailKey                  NVARCHAR( 10),
      @cOption                         NVARCHAR( 1),
      @cToLOC                          NVARCHAR( 10),
      @cTaskDetailCaseID               NVARCHAR( 20),
      @tExtValidate                    VariableTable,
      @b_success                       INT,

      -- 1855 old Step 2 variables
      @nCartonScanned      INT = 0,
      @nCartonCnt          INT = 0,
      @cSuggFromLOC        NVARCHAR( 10),
      @cSuggCartonID       NVARCHAR( 20),
      @cSuggToteId         NVARCHAR( 20),
      @cSuggSKU            NVARCHAR( 20),
      @nSuggQTY            INT = 0,
      @tGetTask            VariableTable,
      @cPickConfirmStatus  NVARCHAR( 1),
      @cCartonType         NVARCHAR( 10),
      @cPickMethod         NVARCHAR( 10),
      @cLockCaseID         NVARCHAR( 20),
      @cTotalToteQty       NVARCHAR( 5),
      @nAssignedToteQty    INT,


      -- 1855 new step1 variables
      @cOrderKey     NVARCHAR( 10) = '',
      @cPickSlipNo   NVARCHAR( 18)

   DECLARE @tTaskDetailKeyList TABLE
   (
      id             INT IDENTITY(1,1),
      TaskDetailKey  NVARCHAR( 10)
   )
   
   -- Set Constant value
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @nStep_ContTask = 10
   SET @nScn_ContTask = 5929

   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SELECT @nMOBRECStep                 = Step,
         @nMOBRECScn                   = Scn,
         @nMenu                        = Menu,
         @cUserName                    = UserName,
         @cSKU                         = V_SKU,
         @cFromLoc                     = V_Loc,
         @cCartonID                    = V_CaseID,
         @cTaskDetailKey               = V_TaskDetailKey,
         @cPickSlipNo                  = V_PickSlipNo,
         @cWaveKey                     = V_WaveKey,
         @nSuggQty                    = V_Integer1, 
         @cCartID                      = V_String8,
         @cSuggFromLOC                 = V_String9,
         @cSuggCartonID                = V_String10,
         @cSuggSKU                     = V_String11,
         @cGroupKey                    = V_String12,
         @cPickConfirmStatus           = V_String17,
         @cPickZone                    = V_String24,
         @cMethod                      = V_String25,
         @cResult01                    = V_String26,
         @cResult02                    = V_String27,
         @cResult03                    = V_String28,
         @cResult04                    = V_String29,
         @cResult05                    = V_String30,
         @cSuggToteId                  = V_String31,
         @cCartPickMethod              = V_String41,
         @cContinuePickOnAssignedCart  = V_String42,
         @cPickNoMixWave               = V_String43,
         @cExtendedScnSP               = V_String44,
         @cTotalToteQty                = C_String1
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Before Main Logic', @nMOBRECScn AS MobScn, @nMOBRECStep AS MobStep, @nMenu AS Menu, @cUserName AS UserName
      SELECT * FROM @tExtScnData
   END

   -- Get data from the table
   SELECT @cOption = Value FROM @tExtScnData WHERE Variable = '@cOption'
   

   IF @nFunc = 1855
   BEGIN
      --Generic ESC handling

      -- redirect to 1st new screen
      IF @nScn = 5920 AND @nStep = 1 AND @nAction = 0
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @nAfterScn = 6414
         SET @nAfterStep = 99 
         GOTO Quit
      END-- generic back to 1st screen
      ELSE IF @nScn=5921 AND @nStep = 2 AND @nAction = 0
      BEGIN
         SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
            AND   TaskType = 'ASTCPK'      
            AND   [Status] = '3'      
            AND   Groupkey = @cGroupKey      
            AND   UserKey = @cUserName      
            AND   DeviceID = @cCartID
            AND   DropID <> ''      
                  
         -- Prepare next screen var        
         SET @cOutField01 = @cCartPickMethod        
         SET @cOutField02 = @cCartID        
         SET @cOutField03 = @cResult01        
         SET @cOutField04 = @cResult02        
         SET @cOutField05 = @cResult03        
         SET @cOutField06 = @cResult04        
         SET @cOutField07 = @cResult05        
         SET @cOutField08 = ''        
         SET @cOutField09 = @nCartonScanned        
         SET @cOutField10 = IIF( @cPickZone = 'PICK', '', @cTotalToteQty )
         
         EXEC rdt.rdtSetFocusField @nMobile, 8      
         
         -- Go to next screen        
         SET @nAfterScn = 6416 -- New Screen 2     
         SET @nAfterStep = 99

      END -- back to 2nd screen
      -- generic esc handling end

      --Screnn logic
      IF @nMOBRECStep = 0
      BEGIN
         IF @nAction = 0 -- new screen
         BEGIN
            IF @nInputKey = 1 --Enter
            BEGIN
               SET @cOutField01 = '' -- PickZone
               EXEC rdt.rdtSetFocusField @nMobile, 1 
               SET @nAfterScn = 6414
               SET @nAfterStep = 99
               GOTO Quit
            END
            ELSE IF @nInputKey = 0 --ESC
            BEGIN
               --Back to Menu
               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType = '9', -- Sign-out
                  @cUserID     = @cUserName,
                  @nMobileNo   = @nMobile,
                  @nFunctionID = @nFunc,
                  @cFacility   = @cFacility,
                  @cStorerKey  = @cStorerKey,
                  @nStep       = @nStep

               -- Back to menu
               SET @nScn  = @nMenu
               SET @nStep = 0
               SET @cOutField01 = ''
               SET @cOutField02 = ''
               SET @cOutField03 = ''
               SET @cOutField04 = ''

               GOTO Quit
            END --inputkey 0
         END -- action 0

         GOTO Quit
      END -- step 0
      ELSE IF @nMOBRECStep = 99
      BEGIN
         IF @nMOBRECScn = 6414 -- 1st Screen in 1855 for LVSUSA
         /************************************************************************************        
            Scn = 6414. Scan Cart Id w. PickSlipNo     
            PickZone    (field01, input)        
            Cart ID     (field02, input)        
            Method      (field03, input)      
            PickSlipNo  (field04, input)        
         ************************************************************************************/  
         BEGIN
            IF @nInputKey = 0
            BEGIN
               --Back to Menu
               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType = '9', -- Sign-out
                  @cUserID     = @cUserName,
                  @nMobileNo   = @nMobile,
                  @nFunctionID = @nFunc,
                  @cFacility   = @cFacility,
                  @cStorerKey  = @cStorerKey,
                  @nStep       = @nStep

               -- Back to menu
               SET @nAfterScn  = @nMenu
               SET @nAfterStep = 0

               --reset 1st screen values
               SET @cOutField01 = ''
               SET @cOutField02 = ''
               SET @cOutField03 = ''
               SET @cOutField04 = ''

            END -- SCN6414 New screen 1 esc
            ELSE IF @nInputKey = 1 -- 
            BEGIN
               -- Screen mapping          
               SET @cPickZone = @cInField01      
               SET @cCartID = @cInField02          
               SET @cMethod = @cInField03
               SET @cPickSlipNo = @cInField04          
                  
               -- Retain value          
               SET @cOutField01 = @cInField01          
               SET @cOutField02 = @cInField02          
               SET @cOutField03 = @cInField03
               SET @cOutField04 = @cInField04          

               -- Check blank          
               IF @cPickZone = ''          
               BEGIN          
                  SET @nErrNo = 171801          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone          
                  EXEC rdt.rdtSetFocusField @nMobile, 1          
                  GOTO Quit          
               END      

               IF @cPickZone = 'PICK'
               BEGIN
                  IF @cContinuePickOnAssignedCart = '1' AND @cCartID <> ''      
                  BEGIN      
                     IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                 AND   TaskType = 'ASTCPK'      
                                 AND   [Status] = '3'      
                                 AND   Groupkey <> ''      
                                 AND   UserKey = @cUserName      
                                 AND   DeviceID = @cCartID
                                 AND   DropID <> '')      
                     BEGIN      
                        SET @cOutField01 = ''      
                           
                        SET @nAfterScn = @nScn_ContTask      
                        SET @nAfterStep = @nStep_ContTask      
                           
                        GOTO SCN6414_Return_Value      
                     END      
                  END   -- Comment out Continue Pick Logic for further investigation    

                  --FCR-652 Validate PSNO
                  IF @cPickSlipNo = ''
                  BEGIN          
                     SET @nErrNo = 220751          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlip No          
                     EXEC rdt.rdtSetFocusField @nMobile, 1          
                     GOTO Quit          
                  END
                  --FCR-652 Validate PSNO end

                  --v1.3 Scanned PSNO is valid
                  IF NOT EXISTS (SELECT 1 FROM PickHeader WITH (NOLOCK)
                              WHERE PickHeaderKey = @cPickSlipNo)
                  BEGIN          
                     SET @nErrNo = 220762          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO not found          
                     EXEC rdt.rdtSetFocusField @nMobile, 1          
                     GOTO Quit          
                  END
                  --Scanned PSNO is valid
                  
                  SET @cWaveKey = ''
                  SELECT TOP 1 @cWaveKey = PKD.WaveKey FROM PICKHEADER PKH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PKD WITH (NOLOCK)
                        ON PKH.StorerKey = PKD.Storerkey AND PKH.OrderKey = PKD.OrderKey
                  WHERE PKH.StorerKey = @cStorerKey
                     AND PKH.PickHeaderKey = @cPickSlipNo

                  SET @cWaveKey = ISNULL(@cWaveKey, '')

                  IF @cWaveKey = ''
                  BEGIN
                     SET @nErrNo = 220752          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoWaveKey Found          
                     EXEC rdt.rdtSetFocusField @nMobile, 4
                     SET @cOutField04 = ''          
                     GOTO Quit
                  END

                  IF @bDebugFlag = 1
                     SELECT @cPickSlipNo AS PSNO, @cWaveKey AS WaveKey

                  --FCR-652 Validate PSNO end

                  -- v1.3 Jackc Check there is available task under Wave
                  IF NOT EXISTS ( SELECT 1      
                                 FROM dbo.TaskDetail TD WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                 AND   TaskType = 'ASTCPK'      
                                 AND   [Status] = '0'      
                                 AND   Groupkey = ''      
                                 AND   UserKey = ''      
                                 AND   DeviceID = ''    
                                 AND   DropID = ''
                                 AND   WaveKey = @cWaveKey
                                 )
                  BEGIN      
                     SET @nErrNo = 220758        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No open task        
                     EXEC rdt.rdtSetFocusField @nMobile, 1          
                     GOTO Quit      
                  END 
                  --v1.3 Jackc Check there is available task under Wave  
                  -- Check pickzone valid          
                  IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                                 JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)    
                                 WHERE TD.Storerkey = @cStorerKey      
                                 AND   TD.TaskType = 'ASTCPK'      
                                 AND   TD.[Status] = '0'      
                                 AND   TD.Groupkey = ''      
                                 AND   TD.UserKey = ''      
                                 AND   TD.DeviceID = ''
                                 AND   TD.WaveKey = @cWaveKey -- FCR-652 add wavekey by JACKC
                                 AND   LOC.Facility = @cFacility       
                                 AND   LOC.PickZone = @cPickZone)          
                  BEGIN --FCR 652 change err msg by JACKC         
                     SET @nErrNo = 220753          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKZone NoTask         
                     EXEC rdt.rdtSetFocusField @nMobile, 1          
                     SET @cOutField01 = ''          
                     GOTO Quit          
                  END          
                  SET @cOutField01 = @cPickZone          
                           
                  -- Check blank          
                  IF @cCartID = ''          
                  BEGIN          
                     SET @nErrNo = 171803          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID          
                     EXEC rdt.rdtSetFocusField @nMobile, 2          
                     GOTO Quit          
                  END          
                     
                  -- Check cart valid          
                  IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)       
                                 WHERE DeviceType = 'CART'       
                                 AND   DeviceID = @cCartID)          
                  BEGIN          
                     SET @nErrNo = 171804          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID          
                     EXEC rdt.rdtSetFocusField @nMobile, 2          
                     SET @cOutField02 = ''          
                     GOTO Quit          
                  END          
                     
                  -- Check cart use by other          
                  IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)       
                              WHERE Storerkey = @cStorerKey      
                              AND   TaskType = 'ASTCPK'      
                              AND   [STATUS] = '3'
                              --AND   DeviceID = @cCartonID      
                              AND   DeviceID = @cCartID     -- Fix original bug. Jackc  
                              AND   UserKey <> @cUserName)          
                  BEGIN          
                     SET @nErrNo = 171805          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use          
                     EXEC rdt.rdtSetFocusField @nMobile, 2          
                     SET @cOutField02 = ''          
                     GOTO Quit          
                  END

                  --v1.3 Check scanned cart in step1 but not start to scan carton
                  IF EXISTS ( SELECT 1 FROM rdt.RDTMOBREC WITH (NOLOCK)
                              WHERE Func = @nFunc
                                 AND Step = 99
                                 AND Scn = 6416
                                 AND V_string8 = @cCartID -- CartID
                                 AND UserName <> @cUserName)
                  BEGIN         
                     SET @nErrNo = 220761          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use          
                     EXEC rdt.rdtSetFocusField @nMobile, 2          
                     SET @cOutField02 = ''          
                     GOTO Quit          
                  END
                  --v1.3 Check scanned cart in step1 but not start to scan carton
                           
                  SET @cOutField02 = @cCartID          
                     
                  -- Check blank          
                  IF @cMethod = ''          
                  BEGIN          
                     SET @nErrNo = 171806          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Method          
                     EXEC rdt.rdtSetFocusField @nMobile, 3          
                     GOTO Quit          
                  END          
                     
                  -- Check Method valid          
                  SELECT @cCartPickMethod = Long      
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'TMPickMtd'      
                  AND   Code = @cMethod      
                  AND   Storerkey = @cStorerKey      
                        
                  IF ISNULL( @cCartPickMethod, '') = ''      
                  BEGIN          
                     SET @nErrNo = 171807          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Method          
                     EXEC rdt.rdtSetFocusField @nMobile, 3          
                     SET @cOutField03 = ''          
                     GOTO Quit          
                  END          
                  
                  DECLARE @n INT      
                  SELECT @n = CHARINDEX(',', @cCartPickMethod)      
                  IF @n > 0      
                  BEGIN      
                     DECLARE @tPickMethod TABLE ( Method    NVARCHAR( 20) )      
                     INSERT INTO @tPickMethod (Method) VALUES (LEFT( @cCartPickMethod, @n-1))      
                     INSERT INTO @tPickMethod (Method) VALUES (LTRIM(SUBSTRING( @cCartPickMethod, @n+1, 20)))      
                  END      
                  ELSE      
                     INSERT INTO @tPickMethod (Method) VALUES (@cCartPickMethod)      
                           
                  -- Check pickzone + method valid          
                  IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                                 JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)       
                                 WHERE TD.Storerkey = @cStorerKey      
                                 AND   TD.TaskType = 'ASTCPK'      
                                 AND   TD.[Status] = '0'      
                                 AND   TD.Groupkey = ''      
                                 AND   TD.UserKey = ''      
                                 AND   TD.DeviceID = ''      
                                 --AND   TD.PickMethod = @cCartPickMethod      
                                 AND   LOC.Facility = @cFacility       
                                 AND   LOC.PickZone = @cPickZone      
                                 AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method))      
                  BEGIN          
                     SET @nErrNo = 171808          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Method          
                     EXEC rdt.rdtSetFocusField @nMobile, 3          
                     SET @cOutField03 = ''          
                     GOTO Quit          
                  END          
                  SET @cOutField03 = @cMethod          
                  
                     
                  -- Extended validate        
                  IF @cExtendedValidateSP <> ''        
                  BEGIN        
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')        
                     BEGIN        
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
                           ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +        
                           ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
                  
                        SET @cSQLParam =        
                           ' @nMobile        INT,           ' +        
                           ' @nFunc          INT,           ' +        
                           ' @cLangCode      NVARCHAR( 3),  ' +        
                           ' @nStep          INT,           ' +        
                           ' @nInputKey      INT,           ' +        
                           ' @cFacility      NVARCHAR( 5),  ' +        
                           ' @cStorerKey     NVARCHAR( 15), ' +      
                           ' @cGroupKey      NVARCHAR( 10), ' +        
                           ' @cTaskDetailKey NVARCHAR( 10), ' +      
                           ' @cPickZone      NVARCHAR( 10), ' +        
                           ' @cCartId        NVARCHAR( 10), ' +      
                           ' @cMethod        NVARCHAR( 1),  ' +        
                           ' @cFromLoc       NVARCHAR( 10), ' +        
                           ' @cCartonId      NVARCHAR( 20), ' +        
                           ' @cSKU           NVARCHAR( 20), ' +        
                           ' @nQty           INT,           ' +        
                           ' @cOption        NVARCHAR( 1), ' +        
                           ' @cToLOC         NVARCHAR( 10), ' +      
                           ' @tExtValidate   VariableTable READONLY, ' +         
                           ' @nErrNo         INT           OUTPUT, ' +        
                           ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
                           @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,       
                           @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
                  
                        IF @nErrNo <> 0         
                           GOTO Quit        
                     END        
                  END        
                  
                  --v1.3 Jackc
                  /*
                  DECLARE @cCurCaseID  NVARCHAR( 20)      
                  DECLARE @cNewCaseID  NVARCHAR( 20)      
                  DECLARE @nCtnCount   INT      
                  SET @cCurCaseID = ''      
                  SET @cNewCaseID = ''      
                  SET @nCtnCount = 0
                  */
                  --v1.3 Jackc end      
                        
                  SELECT @nCartLimit = Short      
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'TMPICKMTD'      
                  AND   Code = @cMethod      
                  AND   Storerkey = @cStorerKey      
                  
                  -- (james03)
                  IF @cPickNoMixWave = '1'
                  BEGIN
                     -- FCR-652 Jackc
                     SET @cPickWaveKey = @cWaveKey
                     /*SELECT TOP 1 @cPickWaveKey = TD.WaveKey      
                     FROM dbo.TaskDetail TD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)      
                     WHERE TD.Storerkey = @cStorerKey      
                     AND   TD.TaskType = 'ASTCPK'      
                     AND   TD.[Status] = '0'      
                     AND   TD.Groupkey = ''      
                     AND   TD.UserKey = ''      
                     AND   TD.DeviceID = ''      
                     AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
                     AND   LOC.Facility = @cFacility       
                     AND   LOC.PickZone = @cPickZone        
                     AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
                     ORDER BY CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey*/
                     -- FCR-652 Jackc end      
                  END

                  --V1.2 jackc Generate Groupkey
                  SET @cGroupKey = ''      
                  SET @nErrNo = 0
                  SET @b_success = 1

                  EXECUTE dbo.nspg_GetKey                                      
                     'LVSLOCK',                                  
                     10 ,                                        
                     @cGroupKey OUTPUT,                       
                     @b_success OUTPUT,                           
                     @nErrNo OUTPUT,                                 
                     @cErrmsg OUTPUT                              
                        
                  IF @b_success <> 1      
                  BEGIN      
                     SET @nErrNo = 220756      
                     SET @cErrmsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get groupkey failure       
                  END
                  --V1.2 jackc Generate Groupkey

                  --v1.3 Jackc Remove lock logic from step 1
                  /* Remove task lock logic in base 1855 step1*/
                  --v1.3 Jackc Remove lock logic from step 1       
                  
                  IF @nErrNo <> 0      
                     GOTO Quit      
                  
                  SET @cResult01 = ''      
                  SET @cResult02 = ''      
                  SET @cResult03 = ''      
                  SET @cResult04 = ''      
                  SET @cResult05 = ''      
                  
                  --v1.3 Jackc No need to show matrix on step2
                  /*
                  -- Draw matrix           
                  SET @nNextPage = 0            
                  EXEC rdt.rdt_TM_Assist_ClusterPick_Matrix         
                     @nMobile          = @nMobile,         
                     @nFunc            = @nFunc,         
                     @cLangCode        = @cLangCode,         
                     @nStep            = @nStep,         
                     @nInputKey        = @nInputKey,         
                     @cFacility        = @cFacility,         
                     @cStorerKey       = @cStorerKey,         
                     @cPickZone        = @cPickZone,         
                     @cCartID          = @cCartID,        
                     @cMethod          = @cMethod,      
                     @cResult01        = @cResult01   OUTPUT,          
                     @cResult02        = @cResult02   OUTPUT,          
                     @cResult03        = @cResult03   OUTPUT,          
                     @cResult04        = @cResult04   OUTPUT,             
                     @cResult05        = @cResult05   OUTPUT,          
                     @nNextPage        = @nNextPage   OUTPUT,          
                     @nErrNo           = @nErrNo      OUTPUT,          
                     @cErrMsg          = @cErrMsg     OUTPUT 
                        
                  IF @nErrNo <> 0            
                     GOTO Quit            
                  */ 
                  --v1.3 Jackc No need to show matrix on step2 end 

                  -- Prepare next screen var        
                  SET @cOutField01 = @cCartPickMethod        
                  SET @cOutField02 = @cCartID        
                  SET @cOutField03 = @cResult01        
                  SET @cOutField04 = @cResult02        
                  SET @cOutField05 = @cResult03        
                  SET @cOutField06 = @cResult04        
                  SET @cOutField07 = @cResult05        
                  SET @cOutField08 = ''        
                  SET @cOutField09 = 0        
                  SET @cOutField10 = ''
                        
                  SET @cFromLoc = ''        
                  SET @cCartonID = ''        
                  SET @cSKU = ''        
                  SET @nQTY = 0        
                        
                  -- Go to new screen 2        
                  SET @nAfterScn = 6416        
                  SET @nAfterStep = 99

                  -- FCR-652 Return the values need to be saved to rdtmobrec
                  SCN6414_Return_Value:
                     SET @cUDF01 = @cSKU
                     SET @cUDF02 = CAST(@nQTY AS NVARCHAR(10))
                     SET @cUDF03 = @cFromLoc
                     SET @cUDF04 = @cCartonID
                     SET @cUDF05 = @cTaskDetailKey
                     SET @cUDF06 = @cWaveKey
                     SET @cUDF07 = @cCartID
                     SET @cUDF08 = @cGroupKey
                     SET @cUDF09 = @cPickZone
                     SET @cUDF10 = @cResult01
                     SET @cUDF11 = @cResult02
                     SET @cUDF12 = @cResult03
                     SET @cUDF13 = @cResult04
                     SET @cUDF14 = @cResult05
                     SET @cUDF15 = @cMethod
                     SET @cUDF16 = @cPickSlipNo
               END -- Normal Picking FLow
               ELSE BEGIN --Automation Picking FLow
                  -- Check pickzone valid
                  --Search the First Task
                  SELECT TOP 1 @cTaskDetailKey = TaskDetailKey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) 
                     ON ( TD.FromLoc = LOC.Loc)
                  WHERE TD.Storerkey = @cStorerKey
                     AND TD.TaskType = 'ASTCPK'
                     AND TD.Status = '0'
                     AND TD.Groupkey = ''
                     AND TD.UserKey = ''
                     AND TD.DeviceID = ''
                     AND LOC.Facility = @cFacility
                     AND LOC.PickZone = @cPickZone
                  ORDER BY TD.Priority, TD.TaskDetailKey
                  SELECT @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0
                  BEGIN --FCR 652 change err msg by JACKC
                     SET @nErrNo = 220763
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKZoneNoTask
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     SET @cOutField01 = ''
                     GOTO Quit
                  END

                  -- Check CartID blank
                  IF @cCartID = ''
                  BEGIN
                     SET @nErrNo = 220764
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartID
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     GOTO Quit
                  END
                     
                  -- Check cart valid
                  IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)
                                 WHERE DeviceType = 'CART'
                                    AND DeviceID = @cCartID
                                    AND StorerKey = @cStorerKey)
                  BEGIN
                     SET @nErrNo = 220765
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartID
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     SET @cOutField02 = ''
                     GOTO Quit
                  END
                     
                  -- Check cart use by other
                  IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                              WHERE Storerkey = @cStorerKey
                                 AND TaskType = 'ASTCPK'
                                 AND Status = '3'
                                 AND DeviceID = @cCartID
                                 AND UserKey <> @cUserName)
                  BEGIN
                     SET @nErrNo = 220766
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartInUse
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     SET @cOutField02 = ''
                     GOTO Quit
                  END

                  --v1.3 Check scanned cart in step1 but not start to scan carton
                  IF EXISTS ( SELECT 1 FROM rdt.RDTMOBREC WITH (NOLOCK)
                              WHERE Func = @nFunc
                                 AND Step = 99
                                 AND Scn = 6416
                                 AND V_string8 = @cCartID -- CartID
                                 AND UserName <> @cUserName)
                  BEGIN         
                     SET @nErrNo = 220767
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     SET @cOutField02 = ''
                     GOTO Quit
                  END
                  --v1.3 Check scanned cart in step1 but not start to scan carton
                           
                  SET @cOutField02 = @cCartID
                     
                  -- Check blank
                  IF @cMethod = ''
                  BEGIN
                     SET @nErrNo = 220768
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedMethod
                     EXEC rdt.rdtSetFocusField @nMobile, 3
                     GOTO Quit
                  END
                     
                  -- Check Method valid
                  SELECT @cCartPickMethod = Long,
                     @nCartLimit = Short
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'TMPICKMTD'
                     AND Code = @cMethod
                     AND Storerkey = @cStorerKey

                  IF ISNULL( @cCartPickMethod, '') = ''
                  BEGIN
                     SET @nErrNo = 220769
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidMethod
                     EXEC rdt.rdtSetFocusField @nMobile, 3
                     SET @cOutField03 = ''
                     GOTO Quit
                  END

                  IF ISNULL(TRY_CAST(@nCartLimit AS INT), 0) < 1
                  BEGIN
                     SET @nErrNo = 220770
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidMethod
                     EXEC rdt.rdtSetFocusField @nMobile, 3
                     SET @cOutField03 = ''
                     GOTO Quit
                  END

                  --Generate Groupkey
                  SET @cGroupKey = ''
                  SET @nErrNo = 0

                  SET @b_success = 1
                  EXECUTE dbo.nspg_GetKey
                     'LVSLOCK',
                     10 ,
                     @cGroupKey OUTPUT,
                     @b_success OUTPUT,
                     @nErrNo OUTPUT,
                     @cErrmsg OUTPUT
                        
                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = 220771
                     SET @cErrmsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenGrpKeyFail
                  END
                  --Generate Groupkey

                  IF @nErrNo <> 0
                     GOTO Quit

                  SELECT @nRowCount = COUNT(DISTINCT TD.CaseID)
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) 
                     ON TD.FromLoc = LOC.Loc
                  WHERE TD.Storerkey = @cStorerKey
                     AND TD.TaskType = 'ASTCPK'
                     AND TD.Status = '0'
                     AND TD.Groupkey = ''
                     AND TD.UserKey = ''
                     AND TD.DeviceID = ''
                     AND LOC.Facility = @cFacility
                     AND LOC.PickZone = @cPickZone
                     AND EXISTS (SELECT 1 FROM dbo.TaskDetail TD1 WITH (NOLOCK)
                                 WHERE TD1.StorerKey = @cStorerKey
                                    AND TD1.TaskDetailKey = @cTaskDetailKey
                                    AND TD1.WaveKey = TD.WaveKey
                                    AND TD1.ToLoc = TD.ToLoc)

                  SET @nRowCount = IIF(@nCartLimit <= @nRowCount, @nCartLimit, @nRowCount)

                  INSERT INTO @tTaskDetailKeyList (TaskDetailKey)
                  SELECT TaskDetailKey
                  FROM
                     (SELECT TD.TaskDetailKey, ROW_NUMBER()OVER(PARTITION BY TD.CaseID ORDER BY TD.Priority, TD.TaskDetailKey) AS row#
                     FROM dbo.TaskDetail TD WITH (NOLOCK)
                     INNER JOIN dbo.LOC LOC WITH (NOLOCK) 
                        ON TD.FromLoc = LOC.Loc
                     WHERE TD.Storerkey = @cStorerKey
                        AND TD.TaskType = 'ASTCPK'
                        AND TD.Status = '0'
                        AND TD.Groupkey = ''
                        AND TD.UserKey = ''
                        AND TD.DeviceID = ''
                        AND LOC.Facility = @cFacility
                        AND LOC.PickZone = @cPickZone
                        AND EXISTS (SELECT 1 FROM dbo.TaskDetail TD1 WITH (NOLOCK)
                                    WHERE TD1.StorerKey = @cStorerKey
                                       AND TD1.TaskDetailKey = @cTaskDetailKey
                                       AND TD1.WaveKey = TD.WaveKey
                                       AND TD1.ToLoc = TD.ToLoc)) AS t
                  WHERE t.row# <= @nRowCount

                  SET @cTotalToteQty = ISNULL(TRY_CAST(@nRowCount AS NVARCHAR(5)), 0)

                  --Lock the Tasks
                  UPDATE TaskDetail WITH(ROWLOCK)
                  SET 
                     UserKey = @cUserName,
                     DeviceID = @cCartID,
                     Groupkey = @cGroupKey,
                     Status = '3'
                  WHERE StorerKey = @cStorerKey
                     AND EXISTS(SELECT 1 FROM @tTaskDetailKeyList AS TDL WHERE TaskDetail.TaskDetailKey = TDL.TaskDetailKey)

                  SET @cOutField01 = @cCartPickMethod
                  SET @cOutField02 = @cCartID
                  SET @cOutField03 = ''
                  SET @cOutField04 = ''
                  SET @cOutField05 = ''
                  SET @cOutField06 = ''
                  SET @cOutField07 = ''
                  SET @cOutField08 = ''
                  SET @cOutField09 = '0'
                  SET @cOutField10 = @cTotalToteQty
                        
                  SET @cUDF01 = ''
                  SET @cUDF02 = ''
                  SET @cUDF03 = ''
                  SET @cUDF04 = ''
                  SET @cUDF05 = @cTaskDetailKey
                  SET @cUDF06 = ''
                  SET @cUDF07 = @cCartID
                  SET @cUDF08 = @cGroupKey
                  SET @cUDF09 = @cPickZone
                  SET @cUDF10 = ''
                  SET @cUDF11 = ''
                  SET @cUDF12 = ''
                  SET @cUDF13 = ''
                  SET @cUDF14 = ''
                  SET @cUDF15 = @cMethod
                  SET @cUDF16 = ''
                  SET @cUDF17 = @cTotalToteQty
                        
                  -- Go to new screen 2
                  SET @nAfterScn = 6416
                  SET @nAfterStep = 99
               END --Automation Picking FLow
   
            END -- SCN 6414 Screen 1 Inputkey 1

            GOTO Quit
         END -- SCN 6414 new screen1
         ELSE IF @nMOBRECScn = 6416 -- 2nd screen in 1855 for LVSUSA
         /************************************************************************************        
            Scn = 6416. Cart ID/Matrix screen        
               Cart ID   (field01)        
               Result01  (field01)            
               Result02  (field02)            
               Result03  (field03)            
               Result04  (field04)            
               Result05  (field05)            
               Result06  (field06)            
               Result07  (field07)            
               Result08  (field08)         
         ************************************************************************************/  
         BEGIN
            SCN6416_Start:
            IF @nInputKey = 0
            BEGIN
               -- Prepare next screen var        
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
               SET @cOutField12 = ''         
               SET @cOutField13 = ''        
                     
               EXEC rdt.rdtSetFocusField @nMobile, 1      
                     
               -- Go to next screen        
               SET @nAfterScn = 5927 -- Unassign Cart screen        
               SET @nAfterStep = 8 

            END -- SCN 6416 new step 2 Esc
            ELSE IF @nInputKey = 1
            BEGIN
               -- Screen mapping        
               SET @cCartonId = @cInField08
               SET @nCartLimit = ISNULL(TRY_CAST(@cTotalToteQty AS INT), 0)

               IF @cPickZone = 'PICK'
               BEGIN
                  -- FCR-652 Move to top for the validation change
                  SELECT @nCartLimit = Short      
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'TMPICKMTD'      
                     AND   Code = @cMethod      
                     AND   Storerkey = @cStorerKey
                  -- FCR-652 Move to top for the validation change  end       
                  
                  -- Validate blank        
                  IF ISNULL( @cCartonId, '') = ''        
                  BEGIN        
                     SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
                     FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey = @cGroupKey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID <> ''      
                  
                     IF @nCartonScanned = 0      
                     BEGIN      
                        SET @nErrNo = 171810     
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Tote Id        
                        GOTO Step_Matrix_Fail      
                     END      

                     --FCR-652 Move to the top of inputkey = 1
                     /*
                     SELECT @nCartLimit = Short      
                     FROM dbo.CODELKUP WITH (NOLOCK)      
                     WHERE LISTNAME = 'TMPICKMTD'      
                     AND   Code = @cMethod      
                     AND   Storerkey = @cStorerKey*/      
                           
                     SELECT @nCartonCnt = COUNT( DISTINCT DropID)      
                     FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                        AND   TaskType = 'ASTCPK'      
                        AND   [Status] IN ( '3', '5')      
                        AND   Groupkey = @cGroupkey      
                        AND   UserKey = @cUserName      
                        AND   DeviceID = @cCartID      
                        AND   DropID <> ''      
                     
                     --FCR-652 Do not check cnt< cartLimit
                     /*IF @nCartonCnt < @nCartLimit AND                   
                     EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                 AND   TaskType = 'ASTCPK'      
                                 AND   [Status] IN ( '3', '5')      
                                 AND   Groupkey = @cGroupkey      
                                 AND   UserKey = @cUserName      
                                 AND   DeviceID = @cCartID      
                                 AND   DropID = '')      
                     BEGIN      
                        SET @nErrNo = 171837                  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoreCtnToScan                  
                        GOTO Step_Matrix_Fail      
                     END */
                     --FCR-652 Do not check cnt< cartLimit
                     IF @nCartonCnt > @nCartLimit
                     BEGIN
                        SET @nErrNo = 220754                  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --reach cart limit                  
                        GOTO Step_Matrix_Fail
                     END                
                     ELSE  --Something scanned      
                     BEGIN
                        --v1.3 JACKC No needs to release task as lock task per scanned carton
                        /*
                        --FCR-652 release tasks which not scanned
                        UPDATE dbo.TaskDetail WITH (ROWLOCK) SET       
                           STATUS = '0',      
                           UserKey = '',      
                           Groupkey = '',       
                           DeviceID = '',      
                           DropID = '',      
                           StatusMsg = '',      
                           EditWho = @cUserName,       
                           EditDate = GETDATE()
                        WHERE Storerkey = @cStorerKey      
                           AND   TaskType = 'ASTCPK'      
                           AND   [Status] = '3'      
                           AND   Groupkey = @cGroupKey      
                           AND   UserKey = @cUserName      
                           AND   DeviceID = @cCartID
                           AND   DropID = ''
                        --FCR-652 release tasks which not scanned end
                        */
                        --v1.3 JACKC No needs to release task as lock task per scanned carton end


                        --Get task for next loc        
                        SET @nErrNo = 0        
                        SET @cSuggFromLOC = ''        
                        EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTask]         
                           @nMobile          = @nMobile,        
                           @nFunc            = @nFunc,        
                           @cLangCode        = @cLangCode,        
                           @nStep            = @nStep,        
                           @nInputKey        = @nInputKey,        
                           @cFacility        = @cFacility,        
                           @cStorerKey       = @cStorerKey,        
                           @cGroupKey        = @cGroupKey,        
                           @cCartId          = @cCartId,        
                           @cType            = 'NEXTLOC',        
                           @cTaskDetailKey   = @cTaskDetailKey OUTPUT,        
                           @cFromLoc         = @cSuggFromLOC   OUTPUT,        
                           @cCartonId        = @cSuggCartonID  OUTPUT,        
                           @cToteId          = @cSuggToteId    OUTPUT,      
                           @cSKU             = @cSuggSKU       OUTPUT,        
                           @nQty             = @nSuggQty       OUTPUT,        
                           @tGetTask         = @tGetTask,         
                           @nErrNo           = @nErrNo         OUTPUT,        
                           @cErrMsg          = @cErrMsg        OUTPUT        
                  
                        IF @nErrNo <> 0        
                           GOTO Quit        
                  
                        -- Prepare next screen var        
                        SET @cOutField01 = @cCartPickMethod      
                        SET @cOutField02 = @cSuggFromLOC         
                        SET @cOutField03 = ''      
                  
                        -- Go to next screen        
                        SET @nAfterScn = 5922 -- From Loc screen        
                        SET @nAfterStep = 3        

                        GOTO SCN6416_Return_Value    
                        --GOTO Quit      
                     END      
                  END -- CartonID = ''

                  -- v1.3 JACKC Carton ID under current wave
                  IF NOT EXISTS ( SELECT 1
                                 FROM TaskDetail WITH (NOLOCK)
                                 WHERE Storerkey = @cStorerKey
                                    AND WaveKey = @cWaveKey
                                    AND Caseid = @cCartonID
                                 )
                  BEGIN
                     SET @nErrNo = 220757        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not under Wave        
                     GOTO Step_Matrix_Fail
                  END
                  --v1.3 Jackc  Carton ID under current wave end       
                  
                  IF EXISTS ( SELECT 1       
                              FROM dbo.TaskDetail WITH (NOLOCK)      
                              WHERE Storerkey = @cStorerKey      
                              AND   TaskType = 'ASTCPK'      
                              AND   [Status] = '3'      
                              AND   Groupkey = @cGroupKey      
                              AND   UserKey = @cUserName      
                              AND   DeviceID = @cCartID      
                              AND   DropID = @cCartonId)      
                  BEGIN        
                     SET @nErrNo = 171811        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned        
                     GOTO Step_Matrix_Fail        
                  END        
                  
                  -- Check if all carton assigned
                  -- v1.3 Jackc Change logic due to no pre-lock tasks      
                  /*IF NOT EXISTS ( SELECT 1      
                                 FROM dbo.TaskDetail WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                 AND   TaskType = 'ASTCPK'      
                                 AND   [Status] = '3'      
                                 AND   Groupkey = @cGroupKey      
                                 AND   UserKey = @cUserName      
                                 AND   DeviceID = @cCartID      
                                 AND   DropID = '') */
                  IF NOT EXISTS ( SELECT 1      
                                 FROM dbo.TaskDetail TD WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                    AND   TaskType = 'ASTCPK'      
                                    AND   [Status] = '0'      
                                    AND   Groupkey = ''      
                                    AND   UserKey = ''      
                                    AND   DeviceID = ''    
                                    AND   DropID = ''
                                    AND   UserKey = ''
                                    AND   CaseID = @cCartonID
                                    AND   WaveKey = @cWaveKey
                                 )
                  BEGIN
                     IF NOT EXISTS ( SELECT 1      
                                    FROM dbo.TaskDetail TD WITH (NOLOCK)      
                                    WHERE Storerkey = @cStorerKey      
                                       AND   TaskType = 'ASTCPK'      
                                       AND   [Status] = '3'      
                                       AND   Groupkey <> ''      
                                       AND   UserKey <> ''      
                                       AND   DeviceID <> ''    
                                       AND   DropID <> ''
                                       AND   CaseID = @cCartonID
                                       AND   WaveKey = @cWaveKey
                                    ) -- All task were picked
                     BEGIN
                        SET @nErrNo = 220760        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton Picked        
                        GOTO Step_Matrix_Fail  
                     END
                     ELSE
                     BEGIN       
                        SET @nErrNo = 220759        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton Assigned        
                        GOTO Step_Matrix_Fail  
                     END    
                  END
                  -- v1.3 Jackc Change logic due to no pre-lock tasks end      
                        
                  IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)      
                              WHERE Storerkey = @cStorerKey      
                              AND   DropID = @cCartonID      
                              AND  ([Status] = '4' OR       
                                    [Status] < @cPickConfirmStatus OR       
                                    ([Status] = '3' AND CaseID <> 'SORTED') OR      
                                    ([Status] = '3' AND CaseID <> '')))       
                  BEGIN      
                     SET @nErrNo = 171832        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use        
                     GOTO Step_Matrix_Fail      
                  END      
                        
                  IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                              WHERE Storerkey = @cStorerKey      
                              AND   TaskType = 'ASTCPK'      
                              AND   [Status] < '5' --V1.2, change from 9 to 5, Jackc
                              AND   DropID = @cCartonID)      
                  BEGIN      
                     SET @nErrNo = 171833        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use        
                     GOTO Step_Matrix_Fail      
                  END

                  -- FCR-652 Jack check cannot exceed the cart limit
                  SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
                  FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey = @cGroupKey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID <> ''

                  IF @nCartonScanned = @nCartLimit
                  BEGIN
                     SET @nErrNo = 220754        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reach Cart Limit        
                     GOTO Step_Matrix_Fail
                  END
                  ---- FCR-652 Jack check cannot exceed the cart limit END

                  --v1.3 JACKC Remove the carton validation against on locked task
                  /*
                  -- FCR-652 by Jack Scanned carton must be in the locked task
                  IF NOT EXISTS (SELECT 1      
                                 FROM dbo.TaskDetail WITH (NOLOCK)      
                                 WHERE Storerkey = @cStorerKey      
                                    AND   TaskType = 'ASTCPK'      
                                    AND   [Status] = '3'      
                                    AND   Groupkey = @cGroupKey      
                                    AND   UserKey = @cUserName      
                                    AND   DeviceID = @cCartID      
                                    AND   Caseid = @cCartonID)
                  BEGIN
                     SET @nErrNo = 220755        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCarton        
                     GOTO Step_Matrix_Fail
                  END
                  -- FCR-652 by Jack Scanned carton must be in the locked task
                  */      
                  --v1.3 JACKC Remove the carton validation against on locked task

                  -- Extended validate        
                  IF @cExtendedValidateSP <> ''        
                  BEGIN        
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')        
                     BEGIN        
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
                           ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +        
                           ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
                  
                        SET @cSQLParam =        
                           ' @nMobile        INT,           ' +        
                           ' @nFunc          INT,           ' +        
                           ' @cLangCode      NVARCHAR( 3),  ' +        
                           ' @nStep          INT,           ' +        
                           ' @nInputKey      INT,           ' +        
                           ' @cFacility      NVARCHAR( 5),  ' +        
                           ' @cStorerKey     NVARCHAR( 15), ' +      
                           ' @cGroupKey      NVARCHAR( 10), ' +        
                           ' @cTaskDetailKey NVARCHAR( 10), ' +      
                           ' @cPickZone      NVARCHAR( 10), ' +        
                           ' @cCartId        NVARCHAR( 10), ' +      
                           ' @cMethod        NVARCHAR( 1),  ' +        
                           ' @cFromLoc       NVARCHAR( 10), ' +        
                           ' @cCartonId      NVARCHAR( 20), ' +        
                           ' @cSKU           NVARCHAR( 20), ' +        
                           ' @nQty           INT,           ' +        
                           ' @cOption        NVARCHAR( 1), ' +        
                           ' @cToLOC         NVARCHAR( 10), ' +      
                           ' @tExtValidate   VariableTable READONLY, ' +         
                           ' @nErrNo         INT           OUTPUT, ' +        
                           ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
                           @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,       
                           @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
                  
                        IF @nErrNo <> 0         
                           GOTO Step_Matrix_Fail        
                     END        
                  END        
                     
                  SELECT @cCartonType = UDF01      
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'TMPICKMTD'      
                     AND   Code = @cMethod      
                     AND   Storerkey = @cStorerKey      
                     
                  SET @cPickMethod = ''      
                  SELECT @cPickMethod = Long       
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'TMPICKMTD'      
                     AND   Storerkey = @cStorerKey      
                     AND   UDF01 = SUBSTRING( @cCartonId, 1, 1)      

                  --v1.3 Lock task based on input key. Replace old logic
                  UPDATE dbo.TaskDetail SET
                        STATUS = '3',      
                        UserKey = @cUserName,      
                        Groupkey = @cGroupKey,       
                        DeviceID = @cCartID,             
                        StartTime = GETDATE(),       
                        DropID = @cCartonID,       
                        StatusMsg =  CAST( @nCartonScanned + 1 AS NVARCHAR( 1)) + '-' + @cCartonType,      
                        EditWho = @cUserName,       
                        EditDate = GETDATE()      
                  WHERE Storerkey = @cStorerKey
                     AND Caseid = @cCartonID   
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '0'      
                     AND   Groupkey = ''      
                     AND   UserKey = ''      
                     AND   DeviceID = ''    
                     AND   DropID = ''
                  /*
                  SELECT TOP 1 @cLockCaseID = Caseid--@cLockTaskKey = TaskDetailKey      
                  FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey = @cGroupKey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID = ''      
                     AND   PickMethod = @cPickMethod 
                     AND   Caseid = @cCartonID -- FCR-652 update task caseid = scanned tote id     
                  ORDER BY 1      
                        
                  DECLARE @curLockCase CURSOR      
                  SET @curLockCase = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
                  SELECT TaskDetailKey      
                  FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey = @cGroupKey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   Caseid = @cLockCaseID      
                     AND   DropID = ''      
                  ORDER BY 1    
                  OPEN @curLockCase      
                  FETCH NEXT FROM @curLockCase INTO @cLockTaskKey      
                  WHILE @@FETCH_STATUS = 0      
                  BEGIN      
                     UPDATE dbo.TaskDetail SET       
                        DropID = @cCartonID,       
                        StatusMsg =  CAST( @nCartonScanned + 1 AS NVARCHAR( 1)) + '-' + @cCartonType,      
                        EditWho = @cUserName,       
                        EditDate = GETDATE()      
                     WHERE TaskDetailKey = @cLockTaskKey      
                        
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @nErrNo = 171812        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Fail        
                     GOTO Step_Matrix_Fail      
                     END      
                        
                     FETCH NEXT FROM @curLockCase INTO @cLockTaskKey      
                  END
                  */ 
                  --v1.3 Lock task based on input key. Replace old logic end     
                        
                  -- Prepare next screen var        
                  SET @cOutField01 = @cCartPickMethod        
                  SET @cOutField02 = @cCartID        
                  SET @cOutField03 = @cResult01        
                  SET @cOutField04 = @cResult02        
                  SET @cOutField05 = @cResult03        
                  SET @cOutField06 = @cResult04        
                  SET @cOutField07 = @cResult05        
                  SET @cOutField08 = ''        
                  SET @cOutField09 = @nCartonScanned + 1

                  --FCR-652 Start to pick when total scanned cases reach the cart limit
                  SET @nCartonScanned = @cOutField09
                  IF @nCartonScanned = @nCartLimit
                  BEGIN
                     SET @cInField08 = ''
                     SET @nInputKey = 1
                     GOTO SCN6416_Start
                  END
                  
                  --FCR-652 Start to pick when total scanned cases reach the cart limit end      
                  
                  EXEC rdt.rdtSetFocusField @nMobile, 8

                  Step_Matrix_Fail:                  
                  BEGIN                  
                     -- Reset this screen var                  
                     SET @cCartonID = ''      
                     
                     SET @cOutField08 = ''                  
                  END

                  -- back to new 2 scn
                  --SET @nAfterScn = 6416 -- new screen2
                  --SET @nAfterStep = 99
                  SCN6416_Return_Value:
                     SET @cUDF01 = @cCartonID
                     SET @cUDF02 = @cSuggFromLOC
                     SET @cUDF03 = @cSuggCartonID
                     SET @cUDF04 = @cSuggToteId
                     SET @cUDF05 = @cSuggSKU
                     SET @cUDF06 = CAST(@nSuggQty AS NVARCHAR(10))
                     SET @cUDF07 = @cTaskDetailKey

                  GOTO Quit 
               END -- Normal Pick Flow
               ELSE
               BEGIN -- Automation Pick Flow
                  -- Get assigned task Qty
                  SELECT @nAssignedToteQty = COUNT(DISTINCT DropID)
                  FROM dbo.TaskDetail TD WITH(NOLOCK)
                  WHERE TD.Storerkey = @cStorerKey
                     AND TD.TaskType = 'ASTCPK'
                     AND TD.Status = '3'
                     AND TD.Groupkey = @cGroupkey
                     AND TD.UserKey = @cUserName
                     AND TD.DeviceID = @cCartID
                     AND ISNULL(TD.DropID, '') <> ''

                  -- Validate blank
                  IF ISNULL( @cCartonId, '') = ''
                  BEGIN
                     SELECT @nCartonScanned = COUNT( DISTINCT DropID )
                     FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Storerkey = @cStorerKey
                        AND TaskType = 'ASTCPK'
                        AND Status = '3'
                        AND Groupkey = @cGroupkey
                        AND UserKey = @cUserName
                        AND DeviceID = @cCartID
                        AND DropID <> ''
                  
                     IF @nCartonScanned = 0
                     BEGIN
                        SET @nErrNo = 220772
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedToteId
                        GOTO Step_Matrix_Fail_1
                     END

                     UPDATE TaskDetail WITH (ROWLOCK)
                     SET 
                        Groupkey = '',
                        UserKey = '',
                        DeviceID = '',
                        Status = 0
                     WHERE 
                        Storerkey = @cStorerKey
                        AND TaskType = 'ASTCPK'
                        AND Status = '3'
                        AND Groupkey = @cGroupkey
                        AND UserKey = @cUserName
                        AND DeviceID = @cCartID
                        AND DropID = ''

                     SET @nErrNo = 0
                     SET @cSuggFromLOC = ''
                     EXEC RDT.rdt_TM_Assist_ClusterPick_GetTask
                        @nMobile          = @nMobile,
                        @nFunc            = @nFunc,
                        @cLangCode        = @cLangCode,
                        @nStep            = @nStep,
                        @nInputKey        = @nInputKey,
                        @cFacility        = @cFacility,
                        @cStorerKey       = @cStorerKey,
                        @cGroupKey        = @cGroupKey,
                        @cCartId          = @cCartId,
                        @cType            = 'NEXTLOC',
                        @cTaskDetailKey   = @cTaskDetailKey OUTPUT,
                        @cFromLoc         = @cSuggFromLOC   OUTPUT,
                        @cCartonId        = @cSuggCartonID  OUTPUT,
                        @cToteId          = @cSuggToteId    OUTPUT,
                        @cSKU             = @cSuggSKU       OUTPUT,
                        @nQty             = @nSuggQty       OUTPUT,
                        @tGetTask         = @tGetTask,
                        @nErrNo           = @nErrNo         OUTPUT,
                        @cErrMsg          = @cErrMsg        OUTPUT
               
                     IF @nErrNo <> 0        
                        GOTO Quit        
               
                     -- Prepare next screen var        
                     SET @cOutField01 = @cCartPickMethod
                     SET @cOutField02 = @cSuggFromLOC
                     SET @cOutField03 = ''

                     EXEC rdt.rdtSetFocusField @nMobile, 3
               
                     -- Go to next screen
                     SET @nAfterScn = 5922 -- From Loc screen
                     SET @nAfterStep = 3

                     SET @cUDF01 = @cCartonID
                     SET @cUDF02 = @cSuggFromLOC
                     SET @cUDF03 = @cSuggCartonID
                     SET @cUDF04 = @cSuggToteId
                     SET @cUDF05 = @cSuggSKU
                     SET @cUDF06 = CAST(@nSuggQty AS NVARCHAR(10))
                     SET @cUDF07 = @cTaskDetailKey

                     GOTO Quit
                  END

                  IF EXISTS(SELECT 1 
                           FROM dbo.TaskDetail TD WITH(NOLOCK)
                           WHERE TD.Storerkey = @cStorerKey
                              AND TD.TaskType = 'ASTCPK'
                              AND TD.Groupkey = @cGroupkey
                              AND TD.UserKey = @cUserName
                              AND TD.DeviceID = @cCartID
                              AND DropID = @cCartonId)
                  BEGIN
                     SET @nErrNo = 220774
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateScan
                     GOTO Step_Matrix_Fail_1
                  END

                  IF EXISTS(SELECT 1 
                           FROM dbo.TaskDetail TD WITH(NOLOCK)
                           WHERE TD.Storerkey = @cStorerKey
                              AND TD.TaskType = 'ASTCPK'
                              AND TD.DeviceID <> @cCartID
                              AND DropID = @cCartonId)
                  BEGIN
                     SET @nErrNo = 220775
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote assigned to a different cart
                     GOTO Step_Matrix_Fail_1
                  END

                  SELECT @nCartonCnt = COUNT( DISTINCT DropID )
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                     AND TaskType = 'ASTCPK'
                     AND Status > '0'
                     AND Groupkey = @cGroupkey
                     AND UserKey = @cUserName
                     AND DeviceID = @cCartID
                     AND DropID <> ''
                        
                  IF @nCartonCnt >= @nCartLimit
                  BEGIN
                     SET @nErrNo = 220776
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --220775 Exceed Cart Limitation
                     GOTO Step_Matrix_Fail_1
                  END

                  SELECT TOP 1 @cTaskDetailCaseID = TD.CaseID
                  FROM dbo.TaskDetail TD WITH(NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) 
                     ON TD.FromLoc = LOC.Loc
                  INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK) 
                     ON TD.StorerKey = PD.Storerkey
                     AND TD.TaskDetailKey = PD.TaskDetailKey
                  WHERE TD.Storerkey = @cStorerKey
                     AND TD.TaskType = 'ASTCPK'
                     AND TD.Status = '3'
                     AND TD.Groupkey = @cGroupkey
                     AND TD.UserKey = @cUserName
                     AND TD.DeviceID = @cCartID
                     AND TD.DropID = ''
                     AND PD.Status < @cPickConfirmStatus  
                     AND PD.Status <> '4'  
                  ORDER BY LOC.LogicalLocation, LOC.Loc, TD.Caseid, TD.Sku

                  UPDATE dbo.TaskDetail WITH(ROWLOCK)
                  SET DropID = @cCartonId,
                     StatusMsg = '0'
                  WHERE StorerKey = @cStorerKey
                     AND CaseID = @cTaskDetailCaseID

                  SET @nAssignedToteQty = @nAssignedToteQty + 1

                  Step_Matrix_Fail_1:
                  BEGIN
                     SET @cCartonID = ''
                     SET @cOutField08 = ''
                  END

                  SET @cOutField09 = ISNULL(TRY_CAST(@nAssignedToteQty AS NVARCHAR(5)), 0)
                  SET @cOutField10 = @cTotalToteQty
                  EXEC rdt.rdtSetFocusField @nMobile, 8
               END -- Automation Pick Flow
            END -- SCN 6416 net step 2 enter
         END -- SCN 6416
         
         GOTO Quit

      END -- STEP 99
      ELSE IF @nMOBRECStep = 10
      BEGIN
         IF @nMOBRECScn = 5929
         BEGIN
            IF @cOption = '1'
            BEGIN
               --v1.1 JACKC
               SELECT @cGroupKey = Value
               FROM @tExtScnData
               WHERE Variable = '@cGroupKey'
               --V1.1 JACKC END
               GOTO SCN6416_Start
            END -- option 1

         END -- step 10
      END -- scn 5929
   END -- 1855

   GOTO Quit

Quit:
   IF @bDebugFlag = 1
   BEGIN
      SELECT 'After Main Logic', @nMOBRECScn AS MobScn, @nMOBRECStep AS MobStep, @nMenu AS Menu, @cUserName AS UserName
   END

   UPDATE RDT.RDTMOBREC WITH(ROWLOCK)
   SET C_String1              = @cTotalToteQty
   WHERE Mobile = @nMobile
   
END

GO
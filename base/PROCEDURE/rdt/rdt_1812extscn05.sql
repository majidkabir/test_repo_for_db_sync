SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1812ExtScn05                                    */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: Validate To Lane (MBOL.ExternMBOLKey)                       */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2024-09-23 1.0  James    WMS-26122 Created                           */  
/* 2024-11-11 1.1  PXL009   FCR-1125 Merged 1.0 from v0 branch          */
/*                            the original name is rdt_1812ExtScn01     */
/************************************************************************/  

CREATE   PROC [rdt].[rdt_1812ExtScn05] (  
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData      VariableTable READONLY,
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
   @nAction          INT, --0 Jump Screen, 1 Prepare output fields .....
   @nAfterScn        INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, 
   @cUDF30 NVARCHAR( MAX)  OUTPUT   --to support max length parameter output
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  DECLARE
   @nMOBRECStep      INT,
   @nMOBRECScn       INT,
   @cTaskdetailKey   NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20),
   @cQTY             NVARCHAR( 20),
   @nQTY             INT, 
   @cToLOC           NVARCHAR( 10),
   @cSQL             NVARCHAR(MAX),
   @cSQLParam        NVARCHAR(MAX),
   @cExtendedInfo1   NVARCHAR(20),
   @cExtendedInfoSP  NVARCHAR(20)

   -- Screen constant  
   DECLARE @nScn_ToLane    INT = 6520  
   DECLARE @nScn_Message   INT = 4026  
   DECLARE @nStep_Message  INT = 7  

   -- Session var  
   DECLARE @cToLane        NVARCHAR( 20)
   DECLARE @cSuggToLane    NVARCHAR( 20)
   DECLARE @cExtMbolKey    NVARCHAR( 15)
   DECLARE @cMbolKey       NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cSuggFromLOC   NVARCHAR( 10)
   DECLARE @cSuggID        NVARCHAR( 18)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @nShipperCnt INT = 0
   DECLARE @nFromStep   INT
   DECLARE @nFromScn    INT

   -- Get session info  
   SELECT @nMOBRECStep      = [Step]
      ,@nMOBRECScn          = [Scn]
      ,@nFromScn            = [V_FromScn]
      ,@nFromStep           = [V_FromStep]
      ,@cExtendedInfoSP     = [V_String27]
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   SELECT @cTaskDetailKey = Value FROM @tExtScnData WHERE Variable = '@cTaskDetailKey'
   SELECT @cDropID        = Value FROM @tExtScnData WHERE Variable = '@cDropID'
   SELECT @cToLOC         = Value FROM @tExtScnData WHERE Variable = '@cToLOC'
   SELECT @cQTY           = Value FROM @tExtScnData WHERE Variable = '@cQTY'
   SELECT @nQTY           = 0
   SELECT @nQTY           = CONVERT(INT,@cQTY)      WHERE ISNUMERIC(@cQTY)=1

   IF @nFunc = 1812 -- TM Case Pick  
   BEGIN  
      IF @nMOBRECStep = 6 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 @cSuggToLane = UserDefine03
            FROM dbo.PalletDetail PD WITH (NOLOCK)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.PalletKey = @cDropID
            AND   PD.Status = '9'
            AND   EXISTS ( SELECT 1 -- Look for to lane that scanned before
                           FROM dbo.MBOL M WITH (NOLOCK)
                           WHERE M.ExternMBOLKey = PD.UserDefine03
                           AND   M.Status < '9')
            ORDER BY 1

            -- To Lane screen
            SET @cOutField01 = CASE WHEN ISNULL( @cSuggToLane, '') <> '' THEN @cSuggToLane ELSE '' END -- To Lane
            SET @cOutField02 = ''

            SET @nAfterScn = @nScn_ToLane
            SET @nAfterStep = 99
                     
            GOTO Quit
         END
      END

      IF @nMOBRECStep = 99 -- Customize screens  
      BEGIN  
         IF @nScn = @nScn_ToLane -- To Loc screen   
         BEGIN  
            IF @nInputKey = 1 -- ENTER  
            BEGIN  
               -- Screen mapping  
               SET @cToLane = @cInField02  
  
               -- Check To Lane  
               IF @cToLane = ''  
               BEGIN  
                  SET @nErrNo = 228951  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Lane  
                  GOTO Quit  
               END  
         
               SET @nShipperCnt = 0
               SELECT @nShipperCnt = COUNT( DISTINCT O.ShipperKey)
               FROM dbo.ORDERS O WITH (NOLOCK)
               WHERE O.StorerKey = @cStorerKey
               AND   EXISTS ( SELECT 1
               FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
               JOIN dbo.MBOL M WITH (NOLOCK) ON ( MD.MbolKey = M.MbolKey)
               WHERE O.OrderKey = MD.OrderKey
               AND   M.ExternMbolKey = @cToLane
               AND   M.Status < '9')

               IF @nShipperCnt > 1
               BEGIN  
                  SET @nErrNo = 228952  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Shipper  
                  GOTO Quit  
               END  

               SET @nShipperCnt = 0
               SELECT @nShipperCnt = COUNT( DISTINCT O.ShipperKey)
               FROM dbo.ORDERS O WITH (NOLOCK)
               WHERE O.StorerKey = @cStorerKey
               AND   EXISTS ( SELECT 1
               FROM dbo.PICKDETAIL PD WITH (NOLOCK)
               JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)
               WHERE O.OrderKey = PD.OrderKey
               AND   TD.DropID = @cDropID)

               IF @nShipperCnt > 1
               BEGIN  
                  SET @nErrNo = 228953  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Shipper  
                  GOTO Quit  
               END  

               SELECT TOP 1 
                  @cMbolKey = O.MBOLKey,
                  @cWaveKey = O.UserDefine09
               FROM dbo.PICKDETAIL PD WITH (NOLOCK)
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
               WHERE PD.TaskDetailKey = @cTaskdetailKey
               ORDER BY 1

               IF ISNULL( @cMbolKey, '') <> ''
               BEGIN
                  SELECT @cExtMbolKey = ExternMBOLKey
                  FROM dbo.MBOL WITH (NOLOCK)
                  WHERE MbolKey = @cMbolKey

                  IF ISNULL( @cExtMbolKey, '') <> '' AND ( @cExtMbolKey <> @cToLane)
                  BEGIN  
                     SET @nErrNo = 228954  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Lane  
                     GOTO Quit  
                  END  
               END

               IF EXISTS( SELECT 1
                          FROM dbo.MBOL M WITH (NOLOCK)
                          JOIN dbo.ORDERS O WITH (NOLOCK) ON ( M.MbolKey = O.MBOLKey)
                          WHERE O.StorerKey = @cStorerKey
                          AND   O.UserDefine09 = @cWaveKey
                          AND   M.ExternMBOLKey <> @cToLane
                          AND   M.Status < '9')
               BEGIN  
                  SET @nErrNo = 228955  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Split Lane  
                  GOTO Quit  
               END  

               -- Confirm  
               EXEC rdt.rdt_1812ExtScn05_Confirm  
                  @nMobile, @nFunc, @cLangCode, @nStep OUTPUT, @nScn OUTPUT, @nInputKey, @cFacility, @cStorerkey,   
                  @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @cToLane,   
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,    
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,    
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,    
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,    
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,    
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,   
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,   
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,   
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,   
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,   
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  
                  @nErrNo     OUTPUT,   
                  @cErrMsg    OUTPUT  
               IF @nErrNo <> 0  
                  GOTO Quit  

               -- Prepare next screen var
               SET @cOutField01 = @cToLOC

               SET @nAfterScn = @nScn_Message
               SET @nAfterStep = @nStep_Message

               GOTO Quit  
            END  
              
            IF @nInputKey = 0 -- ESC  
            BEGIN  
               -- Back to FromID screen (full pallet)
               IF @nFromStep = 3
               BEGIN
                  -- Get session info  
                  SELECT 
                     @nFromScn      = V_FromScn,
                     @nFromStep     = V_FromStep,
                     @cPickMethod   = V_String4,
                     @cSuggFromLOC  = V_LOC,
                     @cSuggID       = V_ID
                  FROM rdt.rdtMobRec WITH (NOLOCK)  
                  WHERE Mobile = @nMobile  

                  -- Prepare next screen variable
                  SET @cOutField01 = @cPickMethod
                  SET @cOutField02 = @cDropID
                  SET @cOutField03 = @cSuggFromLOC
                  SET @cOutField04 = @cSuggID
                  SET @cOutField05 = '' -- FromID
               END

               -- Back to close pallet screen
               IF @nFromStep = 5
               BEGIN
                  -- Prepare next screen variable
                  SET @cOutField01 = '' -- Option
               END

               -- Back to short pick screen
               IF @nFromStep = 8
               BEGIN
                  -- Prepare next screen variable
                  SET @cOutField01 = '' -- Option
               END

               -- Back to prev screen
               SET @nAfterScn = @nFromScn
               SET @nAfterStep = @nFromStep
            END  
              
            GOTO Quit  
         END  
      END  
   END  
     
Quit:  
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo1 = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
            '@nAfterStep      INT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 99, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep

         SET @cOutField10 = @cExtendedInfo1
      END
   END

END  
  
SET QUOTED_IDENTIFIER OFF 

GO
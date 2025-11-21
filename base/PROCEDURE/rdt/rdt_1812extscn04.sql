SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**********************************************************************************/
/* Store procedure: rdt_1812ExtScn04                                              */
/* Copyright      : Maersk                                                        */
/* Client         : Unilever                                                      */
/*                                                                                */
/* Purpose:                                                                       */
/*                                                                                */
/* Date       Rev     Author   Purposes                                           */
/* 2024-11-01 1.0.0   YYS027   FCR-989 Min Max Replenishment to add               */
/*                             screen for choicing whether location is empty.     */
/*                             use config ExtScnSP in rdt.StorerConfig            */
/* 2024-11-01 1.2.0   NLT013   UWP-27662 fix a bug: @cOutField01 is set as 0      */
/* 2024-11-01 1.2.1   NLT013   UWP-27662 fix a bug: DropID is invisibe            */
/* 2024-11-12 1.3     PXL009   FCR-1125 v0->v2 Code Sync for CROCS                */
/*                                ExtScnSP call logic change in generic SP        */
/**********************************************************************************/

CREATE    PROC [RDT].[rdt_1812ExtScn04] (
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

   DECLARE @nMOBRECStep     INT
   DECLARE @nMOBRECScn      INT
   DECLARE @cTaskDetailKey  NVARCHAR( 10)
   DECLARE @cListKey        NVARCHAR( 20)
   DECLARE @cDropID         NVARCHAR( 20)
   DECLARE @cSuggSKU        NVARCHAR( 20)
   DECLARE @cSuggFromLOC    NVARCHAR( 10)
   DECLARE @cSuggLOT         NVARCHAR( 10)
   DECLARE @cSuggID         NVARCHAR( 18)
   DECLARE @cQTY            NVARCHAR( 20)
   DECLARE @cQTY_RPL        NVARCHAR( 20)
   DECLARE @nQTY            INT
   DECLARE @nQTY_RPL        INT
   DECLARE @AvlInvQty       INT
   DECLARE @cOption         NVARCHAR(1)
   DECLARE @cLocEmptyOption NVARCHAR(20)   
   DECLARE @cReasonCode     NVARCHAR(10)
   DECLARE @cSQL            NVARCHAR(MAX)
   DECLARE @cSQLParam       NVARCHAR(MAX)
   DECLARE @cReplenFlag     NVARCHAR(20)

   DECLARE @cSKUDesc        NVARCHAR(60)
   DECLARE @cExtendedInfo1  NVARCHAR(20)
   DECLARE @cPUOM           NVARCHAR( 1)
   DECLARE @cPUOM_Div       NVARCHAR(20)
   DECLARE @cPQTY_RPL       NVARCHAR(20)
   DECLARE @cMQTY_RPL       NVARCHAR(20)
   DECLARE @cPQTY           NVARCHAR(20)
   DECLARE @cMQTY           NVARCHAR(20)
   DECLARE @cPUOM_Desc      NVARCHAR( 5)
   DECLARE @cMUOM_Desc      NVARCHAR( 5)
   DECLARE @cLottableCode   NVARCHAR(20)
   DECLARE @nPUOM_Div       INT
   DECLARE @nPQTY_RPL       INT
   DECLARE @nMQTY_RPL       INT
   DECLARE @nPQTY           INT
   DECLARE @nMQTY           INT
   DECLARE @nMorePage       INT

   SELECT @cTaskDetailKey = Value FROM @tExtScnData WHERE Variable = '@cTaskDetailKey'
   SELECT @cDropID        = Value FROM @tExtScnData WHERE Variable = '@cDropID'
   SELECT @cListKey       = Value FROM @tExtScnData WHERE Variable = '@cListKey'
   SELECT @cSuggSKU       = Value FROM @tExtScnData WHERE Variable = '@cSuggSKU'
   SELECT @cSuggFromLOC   = Value FROM @tExtScnData WHERE Variable = '@cSuggFromLOC'
   SELECT @cSuggLOT       = Value FROM @tExtScnData WHERE Variable = '@cSuggLOT'
   SELECT @cSuggID        = Value FROM @tExtScnData WHERE Variable = '@cSuggID'
   SELECT @cQTY           = Value FROM @tExtScnData WHERE Variable = '@cQTY'
   SELECT @cQTY_RPL       = Value FROM @tExtScnData WHERE Variable = '@cQTY_RPL'

   SELECT @cSKUDesc       = Value FROM @tExtScnData WHERE Variable = '@cSKUDesc'
   SELECT @cExtendedInfo1 = Value FROM @tExtScnData WHERE Variable = '@cExtendedInfo1'
   SELECT @cPUOM          = Value FROM @tExtScnData WHERE Variable = '@cPUOM'
   SELECT @cMUOM_Desc     = Value FROM @tExtScnData WHERE Variable = '@cMUOM_Desc'
   SELECT @cPUOM_Desc     = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Desc'
   SELECT @cLottableCode  = Value FROM @tExtScnData WHERE Variable = '@cLottableCode'

   SELECT @cPUOM_Div      = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Div'
   SELECT @cPQTY_RPL      = Value FROM @tExtScnData WHERE Variable = '@cPQTY_RPL'
   SELECT @cMQTY_RPL      = Value FROM @tExtScnData WHERE Variable = '@cMQTY_RPL'
   SELECT @cPQTY          = Value FROM @tExtScnData WHERE Variable = '@cPQTY'
   SELECT @cMQTY          = Value FROM @tExtScnData WHERE Variable = '@cMQTY'

   SELECT @nQTY = 0, @nQTY_RPL = 0, @nPUOM_Div = 0, @nPQTY_RPL = 0, @nMQTY_RPL = 0, @nPQTY = 0, @nMQTY = 0
   SELECT @nQTY           = CONVERT(INT,@cQTY)      WHERE ISNUMERIC(@cQTY)=1
   SELECT @nQTY_RPL       = CONVERT(INT,@cQTY_RPL)  WHERE ISNUMERIC(@cQTY_RPL)=1
   SELECT @nPUOM_Div      = CONVERT(INT,@cPUOM_Div) WHERE ISNUMERIC(@cPUOM_Div)=1
   SELECT @nPQTY_RPL      = CONVERT(INT,@cPQTY_RPL) WHERE ISNUMERIC(@cPQTY_RPL)=1
   SELECT @nMQTY_RPL      = CONVERT(INT,@cMQTY_RPL) WHERE ISNUMERIC(@cMQTY_RPL)=1
   SELECT @nPQTY          = CONVERT(INT,@cPQTY)     WHERE ISNUMERIC(@cPQTY)=1
   SELECT @nMQTY          = CONVERT(INT,@cMQTY)     WHERE ISNUMERIC(@cMQTY)=1

   SELECT @nMOBRECStep      = [Step]
      ,@nMOBRECScn          = [Scn]
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL(@nAction,0) = 0
   BEGIN
      IF @nFunc = 1812
      BEGIN
         IF @nMOBRECStep = 4                 --Scn = 4023 SKU, QTY
         BEGIN
            IF @nInputKey = 1
            BEGIN
               UPDATE rdt.RDTMOBREC WITH(ROWLOCK) SET C_String14 = '' WHERE Mobile = @nMobile
               SET @cReplenFlag = rdt.rdtGetConfig( @nFunc, 'ReplenFlag', @cStorerKey)
               IF @cReplenFlag = '0'
               SET @cReplenFlag = ''
         
               IF @cReplenFlag = '1' 
               BEGIN
                  --so if qty of location in system is zero, RDT will show new empty choice screen, and if non-zero, no screen change, is right?
                  --Sandeep: yes, if it is non zero... then the screen will not be shown... that is the whole idea of asking the user if the location is actually empty

                  SELECT @AvlInvQty = (SUM(LLI.Qty) - SUM(LLI.QtyPicked))       --   + SUM(LLI.PendingMoveIn)) 
                     FROM dbo.SKUXLOC SL WITH (NOLOCK)
                        JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON SL.StorerKey = LLI.StorerKey AND SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC
                  WHERE SL.StorerKey = @cStorerKey
                  AND SL.SKU = @cSuggSKU
                  AND SL.LOC = @cSuggFromLOC
                  --AND SL.LocationType IN ( 'CASE','PALLET','PICK')          --do not check location type for invntory zero checking.

                  IF @nQTY >= @AvlInvQty 
                  BEGIN
                     SET @cOutField01 = '' -- Option            
                     SET @nAfterScn = 4028
                     SET @nAfterStep = 99               -- Goto new screen for choice 1=YES, 9=NO choice location is empty or not.

	
                     GOTO Quit
                  END

               END   --end of IF @cReplenFlag = '1' 
               /*
               -- QTY short
               IF @nQTY < @nQTY_RPL
               BEGIN
                  -- Prepare next screen var
                  SET @cOption = ''
                  SET @cOutField01 = '' -- Option

                  SET @nAfterScn = @nScn + 4
                  SET @nAfterStep = @nStep + 4          --goto Step 8 and scn=4027
               END

               -- QTY fulfill
               IF @nQTY >= @nQTY_RPL                    
               BEGIN
                  -- Prepare next screen var
                  SET @cOption = ''
                  SET @cOutField01 = '' -- Option

                  SET @nAfterScn = @nScn + 1    
                  SET @nAfterStep = @nStep + 1          --goto step 5 and 4024
               END
               */
            END --end of inputkey = 1
         END --end of step 4
/********************************************************************************
Step 99. screen = 4028. Is the location completely empty?
    1 = YES
    9 = NO
    Option (Field01, input)
********************************************************************************/         
         ELSE IF @nMOBRECScn = 4028            --new screen for choice location is empty
         BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               -- Screen mapping
               SET @cOption = @cInField01

               -- Check blank option
               IF @cOption = ''
               BEGIN
                  SET @nErrNo = 228201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
                  SET @cOutField01 = ''
                  GOTO Quit
               END

               -- Check option is valid
               IF @cOption <> '1' AND @cOption <> '9'
               BEGIN
                  SET @nErrNo = 228202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
                  SET @cOption = ''
                  SET @cOutField01 = ''
                  GOTO Quit
               END
               SET @cLocEmptyOption = @cOption     --to Save to V_String14 => C_String14
               UPDATE rdt.RDTMOBREC WITH(ROWLOCK) SET C_String14 = @cLocEmptyOption WHERE Mobile = @nMobile

               IF @cOption='9'
               BEGIN
                  --If the user responds with 9 = NO, please refer to the RDT storer configuration NOREPLENREASON. 
                  --If the Svalue maintained can be found in RDTREASON code list (Code2), then appropriate action has to be taken as mentioned in Code UDF01, Code UDF02, and Code UDF03. 
                  --Please refer to FCR-428 for more information on implementing reason code.
                  DECLARE @cNoReplenReason NVARCHAR(80),
                     --@cCCTaskType       NVARCHAR(60),
                     --@cHoldCheckFlg     NVARCHAR(60),
                     --@cHoldType         NVARCHAR(60),
                     @cStoredProcedure  NVARCHAR(1000)
                  SET @cNoReplenReason = rdt.rdtGetConfig(@nFunc, 'NOREPLENREASON', @cStorerKey)
                  SET @cReasonCode = ISNULL(@cNoReplenReason,'')
                  --SELECT 
                  --   @cReasonCode = Code2,
                  --   @cCCTaskType = UDF01,-- CC task type
                  --   @cHoldType = UDF02 -- Hold type
                  --FROM codelkup WITH(NOLOCK)
                  --WHERE listname = 'RDTREASON'
                  --AND code = @nFunc
                  --AND storerkey = @cStorerKey
                  --AND Code2 = ISNULL(@cNoReplenReason,'')

                  SET @cStoredProcedure = rdt.rdtGetConfig( @nFunc, 'ActRDTreason', @cStorerKey)
                  IF @cStoredProcedure = '0'
                     SET @cStoredProcedure = ''
                        
                  IF @cStoredProcedure <> ''
                  BEGIN
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cStoredProcedure AND type = 'P')
                     BEGIN
                        ---- Generate CC task /or/ Hold Type(LOC/ID/LOT)
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cStoredProcedure) +
                              ' @nMobile, @nFunc, @cStorerKey, ' +
                              ' @cSKU, @cLOC, @cLot, @cID, @cReasonCode, ' +                      
                              ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                        SET @cSQLParam =
                              ' @nMobile         INT                      ' +
                              ',@nFunc           INT                      ' +
                              ',@cStorerKey      NVARCHAR( 15)            ' +
                              ',@cSKU            NVARCHAR( 20)            ' +
                              ',@cLOC            NVARCHAR( 10)            ' +
                              ',@cLot            NVARCHAR( 10)            ' +
                              ',@cID             NVARCHAR( 20)            ' +
                              ',@cReasonCode     NVARCHAR( 20)            ' +                          
                              ',@nErrNo          INT           OUTPUT     ' +
                              ',@cErrMsg         NVARCHAR(250) OUTPUT  '
                        --@cSKU from TaskDetail.SKU
                        --@cLOC from TaskDetail.FromLoc
                        --@cLot from TaskDetail.Lot
                        --@cID  from TaskDetail.FromID

                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                              @nMobile, @nFunc, @cStorerKey,
                              @cSuggSKU, @cSuggFromLOC, @cSuggLOT, @cSuggID, @cReasonCode,
                              @nErrNo OUTPUT, @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                              GOTO Quit
                     END
                  END
                  ----------------------------------------------------
               END

               IF @nQTY < @nQTY_RPL
               BEGIN
                  -- Prepare next screen var
                  SET @cOption = ''
                  SET @cOutField01 = '' -- Option

                  SET @nAfterStep = 8 --@nStep - 2  -- step from 10=>99 to 8          (Short/Close Pallet)
                  SET @nAfterScn = 4027 --@nScn - 1  --screen from 4028 to 4027
               END

               -- QTY fulfill
               IF @nQTY >= @nQTY_RPL
               BEGIN
                  -- Prepare next screen var
                  SET @cOption = ''
                  SET @cOutField01 = '' -- Option

                  SET @nAfterStep = 5 -- @nStep - 5      --step from 10=>99 to 5          (next task /close pallet)
                  SET @nAfterScn = 4024 --@nScn - 4    --screen from 4048 to 4024
               END
            END
            IF @nInputKey = 0 -- ESC pressed, return to SKU screen
            BEGIN
               -- Dynamic lottable
               EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSuggSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 4,
                  @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
                  @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
                  @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
                  @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
                  @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
                  @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
                  @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
                  @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
                  @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
                  @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
                  @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
                  @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
                  @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
                  @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
                  @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
                  @nMorePage   OUTPUT,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT,
                  '',      -- SourceKey
                  @nFunc   -- SourceType         
               -- Prepare next screen variable
               SET @cOutField01 = @cSuggSKU
               SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
               SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
               --SET @cBarcode    = '' -- SKU    --barcode is nvarchar(max), can't be passed as parameter, here
               SET @cUDF30      = ''      --here use @cUDF30 instead
               SET @cOutField09 = ''
               SET @cOutField10 = @cExtendedInfo1
               SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
               SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
               SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
               SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
               SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))
               EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU               
               -- Go to SKU screen (STEP 4)
               SET @nAfterStep = 4
               SET @nAfterScn = 4023
            END
            GOTO Quit
         END  --end if @nScn = 4028
      END

   END
   GOTO Quit

Quit:

END

SET QUOTED_IDENTIFIER OFF 

GO
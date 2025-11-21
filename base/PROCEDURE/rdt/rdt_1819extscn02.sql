SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtScn02                                    */
/* Copyright      :  Maersk                                             */
/*                                                                      */
/* Purpose:       FCR-122  Huqsvarna  New Screen                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-07-08 1.0  CYU027   CREATE                                      */
/* 2024-08-16 1.1  JCH507   Add Extended Upd SP                         */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1819ExtScn02] (
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
   @nAction          INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
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
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nTranCount             INT,
      @cUsr             NVARCHAR( 20),
      @cReasonCode            NVARCHAR(20),
      @cFromLOC               NVARCHAR( 10),
      @cFromID                NVARCHAR( 20),
      @cSuggLOC               NVARCHAR( 10),
      @cPickAndDropLOC        NVARCHAR( 10),
      @cToLOC                 NVARCHAR( 20),
      @cShowPASuccessScn      NVARCHAR( 1),
      @cSQL                   NVARCHAR( MAX), --v1.1 JCH507
      @cSQLParam              NVARCHAR( MAX), --v1.1 JCH507
      @cExtendedUpdateSP      NVARCHAR( 20) --v1.1 JCH507

   SET @cShowPASuccessScn = rdt.RDTGetConfig( @nFunc, 'ShowPASuccessScn', @cStorerKey)
   IF @cShowPASuccessScn = '0'
      SET @cShowPASuccessScn = ''

   --V1.1 JCH507 
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SELECT @cFromID         = V_ID,
         @cFromLOC         = V_LOC,
         @cSuggLOC         = V_String1,
         @cPickAndDropLOC  = V_String2,
         @cToLOC           = V_String3
   FROM RDTMOBREC (NOLOCK)
   WHERE Mobile = @nMobile

   --V1.1 JCH507 END
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtScn02 -- For rollback or commit only our own transaction

   IF @nFunc = 1819
   BEGIN
      IF @nStep = 5
      BEGIN
         IF @nInputKey = 1
         BEGIN

            SET @nAfterScn  = 4115
            SET @nAfterStep= 99
            GOTO Quit
         END
      END -- step5 end
      IF @nStep = 99
      BEGIN
         IF @nInputKey = 1 -- Yes or Send
         BEGIN
            /********************************************************************************
            Scn = 4115. REASON CODE
               REASON CODE:          (field01, input)
            ********************************************************************************/

            SELECT @cFromLOC        = Value FROM @tExtScnData WHERE Variable = '@cFromLOC'
            SELECT @cFromID         = Value FROM @tExtScnData WHERE Variable = '@cFromID'
            SELECT @cSuggLOC        = Value FROM @tExtScnData WHERE Variable = '@cSuggLOC'
            SELECT @cPickAndDropLOC = Value FROM @tExtScnData WHERE Variable = '@cPickAndDropLOC'
            SELECT @cToLOC          = Value FROM @tExtScnData WHERE Variable = '@cToLOC'

            SET @cReasonCode = @cInField01

            SET @cUsr = suser_sname()
            -- Confirm task
            EXEC rdt.rdt_PutawayByID_Confirm @nMobile, @nFunc, @cLangCode, @cUsr, @cStorerKey, @cFacility
               ,@cFromLOC
               ,@cFromID
               ,@cSuggLOC
               ,@cPickAndDropLOC
               ,@cToLOC
               ,@nErrNo    OUTPUT
               ,@cErrMsg   OUTPUT
            IF @nErrNo <> 0
               GOTO TRANS_FAIL

            EXEC rdt.rdt_ActionByReason
                @nMobile          = @nMobile
               ,@nFunc            = @nFunc
               ,@cStorerKey       = @cStorerKey
               ,@cSKU             = ''
               ,@cLoc             = @cSuggLOC
               ,@cLot             = ''
               ,@cID              = ''
               ,@cReasonCode      = @cReasonCode
               ,@nErrNo           = @nErrNo     OUTPUT
               ,@cErrMsg          = @cErrMsg    OUTPUT
            IF @nErrNo <> 0
               GOTO TRANS_FAIL

            --V1.1 JCH507
            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,           ' +
                     '@nFunc           INT,           ' +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,           ' +
                     '@nInputKey       INT,           ' + 
                     '@cFromID         NVARCHAR( 18), ' +
                     '@cSuggLOC        NVARCHAR( 10), ' +
                     '@cPickAndDropLOC NVARCHAR( 10), ' +
                     '@cToLOC          NVARCHAR( 10), ' +
                     '@nErrNo          INT           OUTPUT, ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT  '
      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cOutField01 = ''
                     GOTO TRANS_FAIL
                  END
               END
            END -- END ExtUpd
            --V1.1 JCH507 END

            -- Prep next screen var
            IF @cShowPASuccessScn = '1'
            BEGIN
               -- Go to next screen
               SET @nAfterScn  = 4112
               SET @nAfterStep = 3
            END
            ELSE
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = '' -- FromID

               -- Go to FromID screen
               SET @nAfterScn  = 4110
               SET @nAfterStep= 1
            END

            GOTO Quit

         END

         IF @nInputKey = 0
         BEGIN
            SET @nAfterScn = 4114
            SET @nAfterStep = 5

            GOTO Quit
         END
      END -- step 99 end
   END --1819 end

TRANS_FAIL:
   ROLLBACK TRAN rdt_1819ExtScn02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END;

SET QUOTED_IDENTIFIER OFF

GO
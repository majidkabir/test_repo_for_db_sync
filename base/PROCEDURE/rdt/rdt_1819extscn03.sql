SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtScn03                                    */
/* Copyright      :  Maersk                                             */
/*                                                                      */
/* Purpose:       FCR-2598  Grape Galina                                */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2025-02-24 1.0  CYU027   FCR-2598-Create                             */
/*                                                                      */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1819ExtScn03] (
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
      @cUserName              NVARCHAR( 20),
      @cFromLOC               NVARCHAR( 10),
      @cFromID                NVARCHAR( 20),
      @cSuggLOC               NVARCHAR( 10),
      @cPickAndDropLOC        NVARCHAR( 10),
      @cToLOC                 NVARCHAR( 20),
      @cShowPASuccessScn      NVARCHAR( 1),
      @cDefaultToLOC          NVARCHAR( 1),
      @cSQL                   NVARCHAR( MAX),
      @cSQLParam              NVARCHAR( MAX),
      @cExtendedUpdateSP      NVARCHAR( 20),
      @cExtendedScreenSP      NVARCHAR( 20),
      @cLOCLookupSP           NVARCHAR( 20),
      @cExtendedValidateSP    NVARCHAR( 20),
      @cExtendedInfoSP        NVARCHAR( 20),
      @cExtendedInfo          NVARCHAR( 20),
      @cPAMatchSuggestLOC     NVARCHAR( 1),
      @cOption                NVARCHAR( 10),
      @nPABookingKey          INT


   SELECT
      @cUserName           = UserName,
      @cFromID             = V_ID,
      @cFromLOC            = V_LOC,
      @nPABookingKey       = V_Integer1,
      @cSuggLOC            = V_String1,
      @cPickAndDropLOC     = V_String2,
      @cToLOC              = V_String3,
      @cExtendedValidateSP = V_String4,
      @cExtendedUpdateSP   = V_String5,
      @cExtendedInfoSP     = V_String6,
      @cDefaultToLOC       = V_String9,
      @cShowPASuccessScn   = V_String11,
      @cLOCLookupSP        = V_String18,
      @cPAMatchSuggestLOC  = V_String19
   FROM RDTMOBREC (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nScn = 4111
            BEGIN
               SET @nAfterScn  = 4111
               SET @nAfterStep = 99
               GOTO Quit
            END
         END
      END
      IF @nStep = 99
      BEGIN

         /********************************************************************************
         Step 2. Screen 4111. TO LOC
            FROM ID     (Field01, input)
            Suggest LOC (Field02)
            TO LOC      (Field03)
         ********************************************************************************/
         IF @nScn = 4111
         BEGIN -- Copy from step_2

            IF @nInputKey = 1 -- ENTER
            BEGIN
               -- Screen mapping
               SET @cToLOC = @cInField03

               -- Check blank
               IF @cToLOC = ''
               BEGIN
                  SET @nErrNo = 52753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TO LOC
                  GOTO Step_2_Fail
               END

               SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1819ExtendedScreenSP', @cStorerKey), '')
               SET @nAction = 1
               IF @cExtendedScreenSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
                  BEGIN
                     EXECUTE [RDT].[rdt_1819ExtScnEntry]
                             @cExtendedScreenSP,
                             @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cSuggLOC OUTPUT ,@cToLOC OUTPUT,@cPickAndDropLOC OUTPUT,
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
                             @nAction,
                             @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                             @nErrNo   OUTPUT,
                             @cErrMsg  OUTPUT

                     IF @nErrNo <> 0
                        GOTO Step_2_Fail
                  END
               END

               -- (james04)
               IF @cLOCLookupSP = 1
               BEGIN
                  EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
                       @cToLOC     OUTPUT,
                       @nErrNo     OUTPUT,
                       @cErrMsg    OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_2_Fail
               END

               -- Check TO LOC valid
               IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)
               BEGIN
                  SET @nErrNo = 52754
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
                  GOTO Step_2_Fail
               END

               -- Check if suggested LOC match
               IF (@cToLOC <> @cSuggLOC AND @cPickAndDropLOC = '') OR      -- Not match suggested LOC
                  (@cToLOC <> @cPickAndDropLOC AND @cPickAndDropLOC <> '') -- Not match PND LOC
               BEGIN

                  IF @cPAMatchSuggestLOC = '1'
                  BEGIN
                     SET @nErrNo = 52757
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
                     GOTO Step_2_Fail
                  END
                  ELSE IF @cPAMatchSuggestLOC = '2'
                  BEGIN
                     -- Prepare next screen var
                     SET @cOutField01 = '' -- Option

                     -- Go to LOC not match screen
                     SET @nAfterScn = 4114
                     SET @nAfterStep = 99

                     GOTO Quit
                  END
                  ELSE IF @cPAMatchSuggestLOC = '3'
                  BEGIN

                     -- Prepare next screen var
                     SET @cOutField01 = '' -- Option
                     SET @cOutField02 = @cToLOC
                     SET @cOutField03 = IIF(@cSuggLOC <> '',@cSuggLOC,@cPickAndDropLOC)

                     -- Go to LOC not match screen
                     SET @nAfterScn = 4116
                     SET @nAfterStep = 99
                     GOTO Quit
                  END

               END

               -- Extended validate
               IF @cExtendedValidateSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
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
                        GOTO Step_2_Fail
                  END
               END

               -- Handling transaction
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdtfnc_PutawayByID -- For rollback or commit only our own transaction

               -- Confirm task
               EXEC rdt.rdt_PutawayByID_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
                  ,@cFromLOC
                  ,@cFromID
                  ,@cSuggLOC
                  ,@cPickAndDropLOC
                  ,@cToLOC
                  ,@nErrNo    OUTPUT
                  ,@cErrMsg   OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END

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
                        ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN
                        GOTO Step_2_Fail
                     END
                  END
               END

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

               -- Logging
               EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '4', -- Move
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerKey,
                    @cLocation     = @cFromLOC,
                    @cToLocation   = @cToLOC,
                    @cID           = @cFromID

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
                     SET @nAfterStep = 1
                  END
            END

            IF @nInputKey = 0 -- ESC
            BEGIN
               IF @nPABookingKey <> 0
               BEGIN
                  EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                     ,'' --FromLOC
                     ,'' --FromID
                     ,'' --cSuggLOC
                     ,'' --Storer
                     ,@nErrNo  OUTPUT
                     ,@cErrMsg OUTPUT
                     ,@nPABookingKey = @nPABookingKey OUTPUT
                  IF @nErrNo <> 0
                     GOTO Step_2_Fail

                  SET @nPABookingKey = 0
               END

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
                        GOTO Step_2_Fail
                     END
                  END
               END


               -- Prepare next screen var
               SET @cOutField01 = '' --FromID

               -- Go to FromID screen
               SET @nAfterScn  = 4110
               SET @nAfterStep = 1
            END
            GOTO Quit

            Step_2_Fail:
            BEGIN
               SET @cToLOC = ''
               SET @cOutField03 = '' -- TOLOC
            END


         END

         /********************************************************************************
         Step 5. Scn = 4114.
            LOC not match.
            Scanned LOC:      (Field02)
            Suggested LOC:      (Field03)
            Proceed?
            1 = YES
            2 = NO
            OPTION (Input, Field01)
         ********************************************************************************/
         IF @nScn = 4116 OR @nScn = 4114
         BEGIN
            
            IF @nInputKey = 1
            BEGIN
               SET @cOption = @cInField01

               -- Check blank
               IF @cOption = ''
               BEGIN
                  SET @nErrNo = 73883
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req
                  GOTO Quit
               END

               -- Check optin valid
               IF @cOption NOT IN ('1', '2')
               BEGIN
                  SET @nErrNo = 73884
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option
                  SET @cOutField01 = ''
                  GOTO Quit
               END

               -- Extended validate
               IF @cExtendedValidateSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
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
                        GOTO Quit
                     END
                  END
               END


               IF @cOption = '1' -- YES
               BEGIN

                  -- Handling transaction
                  SET @nTranCount = @@TRANCOUNT
                  BEGIN TRAN  -- Begin our own transaction
                  SAVE TRAN rdtfnc_PutawayByID -- For rollback or commit only our own transaction

                  -- Confirm task
                  EXEC rdt.rdt_PutawayByID_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
                     ,@cFromLOC
                     ,@cFromID
                     ,@cSuggLOC
                     ,@cPickAndDropLOC
                     ,@cToLOC
                     ,@nErrNo    OUTPUT
                     ,@cErrMsg   OUTPUT
                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                        COMMIT TRAN
                     GOTO Quit
                  END

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
                           ROLLBACK TRAN rdtfnc_PutawayByID -- Only rollback change made here
                           WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                              COMMIT TRAN
                           SET @cOutField01 = ''
                           GOTO Quit
                        END
                     END
                  END

                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN

                  -- Logging
                  EXEC RDT.rdt_STD_EventLog
                       @cActionType   = '4', -- Move
                       @cUserID       = @cUserName,
                       @nMobileNo     = @nMobile,
                       @nFunctionID   = @nFunc,
                       @cFacility     = @cFacility,
                       @cStorerKey    = @cStorerKey,
                       @cLocation     = @cFromLOC,
                       @cToLocation   = @cToLOC,
                       @cID           = @cFromID

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
                     SET @nAfterStep = 1
                  END
               END

               IF @cOption = '2' -- No
               BEGIN
                  -- Prepare next screen var
                  SET @cOutField01 = @cFromID
                  SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
                  SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
                  SET @cOutField15 = '' -- ExtendedInfo

                  -- Go to Suggest LOC screen
                  SET @nAfterScn  = 4111
                  SET @nAfterStep = 99

                  -- Extended info
                  IF @cExtendedInfoSP <> ''
                  BEGIN
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
                     BEGIN
                        SET @cExtendedInfo = ''
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                                    ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, ' +
                                    ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
                        SET @cSQLParam =
                                '@nMobile         INT,           ' +
                                '@nFunc           INT,           ' +
                                '@cLangCode       NVARCHAR( 3),  ' +
                                '@nStep           INT,           ' +
                                '@nAfterStep      INT,           ' +
                                '@nInputKey       INT,           ' +
                                '@cFromID         NVARCHAR( 18), ' +
                                '@cSuggLOC        NVARCHAR( 10), ' +
                                '@cPickAndDropLOC NVARCHAR( 10), ' +
                                '@cToLOC          NVARCHAR( 10), ' +
                                '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                                '@nErrNo          INT           OUTPUT, ' +
                                '@cErrMsg         NVARCHAR( 20) OUTPUT  '

                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                             @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT,
                             @nErrNo OUTPUT, @cErrMsg OUTPUT

                        SET @cOutField15 = @cExtendedInfo
                     END
                  END
               END
            END

            IF @nInputKey = 0 -- ESC
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cFromID
               SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
               SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
               SET @cOutField15 = '' -- ExtendedInfo

               -- Go to Suggest LOC screen
               SET @nAfterScn  = 4111
               SET @nAfterStep = 99

               -- Extended info
               IF @cExtendedInfoSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
                  BEGIN
                     SET @cExtendedInfo = ''
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                                 ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT, ' +
                                 ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
                     SET @cSQLParam =
                             '@nMobile         INT,           ' +
                             '@nFunc           INT,           ' +
                             '@cLangCode       NVARCHAR( 3),  ' +
                             '@nStep           INT,           ' +
                             '@nAfterStep      INT,           ' +
                             '@nInputKey       INT,           ' +
                             '@cFromID         NVARCHAR( 18), ' +
                             '@cSuggLOC        NVARCHAR( 10), ' +
                             '@cPickAndDropLOC NVARCHAR( 10), ' +
                             '@cToLOC          NVARCHAR( 10), ' +
                             '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                             '@nErrNo          INT           OUTPUT, ' +
                             '@cErrMsg         NVARCHAR( 20) OUTPUT  '

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                          @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFromID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @cExtendedInfo OUTPUT,
                          @nErrNo OUTPUT, @cErrMsg OUTPUT

                     SET @cOutField15 = @cExtendedInfo
                  END
               END
            END
            GOTO Quit


         END

      END
   END

Quit:
   SET @cUDF01 = @cToLOC


END;

SET QUOTED_IDENTIFIER OFF

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_Driver_CheckIn                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Track the time the Driver Check in At Office             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2009-10-14   1.0  Vicky      Created                                 */
/* 2009-12-02   1.1  Vicky      Fix Parameter                           */
/* 2014-06-12   1.2  James      Change function id due to conflict with */
/*                              other module (james01)                  */
/* 2014-12-02   1.3  ChewKP     SOS#326760 Add Extended Update(ChewKP01)*/
/* 2016-09-30   1.4  Ung        Performance tuning                      */
/* 2018-10-24   1.5  TungGH     Performance                             */
/* 2019-01-02   1.6  Leong      INC0527496 - Bug Fix.                   */
/* 2020-10-22   1.7  Chermaine  WMS-15495 Add Extended Validate(cc01)   */
/* 2020-11-19   1.8  Chermaine  WMS-15680 Add OTMITF config (cc02)      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Driver_CheckIn] (
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
   @i              INT,
   @nTask          INT,
   @cParentScn     NVARCHAR( 3),
   @cOption        NVARCHAR( 1),
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @nPrevScn            INT,
   @nPrevStep           INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cContainerNo        NVARCHAR( 20),
   @cUserID             NVARCHAR( 18),
   @cClickCnt           NVARCHAR(  1),

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),

   @cMenuType           NVARCHAR(1),

   @cSQL                NVARCHAR(1000), -- (ChewKP01)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)
   @cAppointmentNo      NVARCHAR(20),   -- (ChewKP01)
   @cInput01            NVARCHAR(30),   -- (ChewKP01)
   @cInput02            NVARCHAR(30),   -- (ChewKP01)
   @cInput03            NVARCHAR(30),   -- (ChewKP01)
   @cInput04            NVARCHAR(30),   -- (ChewKP01)
   @cActionType         NVARCHAR(10),   -- (ChewKP01)
   @cRefNo1             NVARCHAR(20),   -- (ChewKP01)
   @cDefaultOption      NVARCHAR(1),    -- (ChewKP01)
   @cDefaultCursor      NVARCHAR(1),    -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(30),   -- (cc01)
   @cOTMITF             NVARCHAR(1),    -- (cc02)
   @cMBOLKey            NVARCHAR( 10),  -- (cc02)

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


   @cContainerNo     = V_String1,
   @cAppointmentNo   = V_String2,
   @cExtendedUpdateSP = V_String3,
   @cExtendedValidateSP = V_String4, --(cc01)

   @cActionType       = V_String8,
   @cRefNo1           = V_String9,
   @cDefaultOption    = V_String10,
   @cDefaultCursor    = V_String11,
   @cOTMITF           = V_String12,  --(cc02)

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

-- Screen constant
DECLARE
   @nStep_1          INT,  @nScn_1          INT

SELECT
   @nStep_1          = 1,  @nScn_1          = 2134

IF @nFunc = 857   -- (james01)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 857
   IF @nStep = 1  GOTO Step_1           -- Scn = 2134. Container #
   IF @nStep = 2  GOTO Step_2           -- Scn = 2135. Dynamic Display Field
   IF @nStep = 3  GOTO Step_3           -- Scn = 2136. Dynamic Input Field
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 857
********************************************************************************/
Step_Start:
BEGIN

   -- Prepare label screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''

    -- (ChewKP01)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
   BEGIN
      SET @cExtendedUpdateSP = ''
   END

   -- (ChewKP01)
   SET @cDefaultOption = ''
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
   BEGIN
      SET @cDefaultOption = ''
   END

   SET @cDefaultCursor = ''
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)
   IF @cDefaultOption = '0'
   BEGIN
      SET @cDefaultOption = ''
   END
   
   -- (cc01)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
   -- Storer config 'OTMITF'   --(cc02)
   EXECUTE dbo.nspGetRight  
      NULL, -- Facility  
      @cStorerKey,  
      '',--sku  
      'OTMITF',  
      @b_success  OUTPUT,  
      @cOTMITF    OUTPUT,  
      @nErrNo     OUTPUT,  
      @cErrMsg    OUTPUT  

   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

  IF @nMenu = 55
  BEGIN
    SET @cMenuType = 'I'
  END
  ELSE IF @nMenu = 56
  BEGIN
    SET @cMenuType = 'O'
  END

  EXEC RDT.rdt_STD_EventLog
     @cActionType   = '1', -- Sign In Function
     @cUserID       = @cUserName,
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = '',
     @cRefNo4       = @cMenuType,
     @nStep         = @nStep

   SET @cOutField03 = @cDefaultOption

   EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor

   -- Go to Label screen
   SET @nScn = @nScn_1
   SET @nStep = @nStep_1
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
Scn = 2134. Container # screen
   CONTAINER NO       (field01)
***********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cContainerNo   = RTRIM(@cInField01)
      SET @cAppointmentNo = RTRIM(@cInField02)
      SET @cOption        = RTRIM(@cInField03)

      IF ISNULL(RTRIM(@cContainerNo), '') = '' AND ISNULL(RTRIM(@cAppointmentNo), '') = ''
      BEGIN
         SET @nErrNo = 67944
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Atleast1InputReq
         GOTO Step_1_Fail
      END

      IF @cContainerNo <> ''
      BEGIN
         SET @cRefNo1  = ISNULL(RTRIM(@cContainerNo), '' )
      END
      ELSE
      BEGIN
         SET @cRefNo1  = ISNULL(RTRIM(@cAppointmentNo), '' )
      END

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 67945
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OptionReq
         GOTO Step_1_Fail
      END

      IF ISNULL(RTRIM(@cOption), '') NOT IN ( '1' , '9' )
      BEGIN
         SET @nErrNo = 67946
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidOption
         GOTO Step_1_Fail
      END

--     IF ISNULL(RTRIM(@cContainerNo), '') = ''
--     BEGIN
--         SET @nErrNo = 67941
--         SET @cErrMsg = rdt.rdtgetmessage( 67941, @cLangCode, 'DSP') -- Container Req
--         GOTO Step_1_Fail
--     END

      IF @cOption = '1'
      BEGIN
         SET @cActionType = 12
      END
      ELSE IF @cOption = '9'
      BEGIN
         SET @cActionType = 22
      END
     
      --(cc01)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cContainerNo   NVARCHAR( 20), ' +
                  '@cAppointmentNo NVARCHAR( 20), ' +
                  '@nInputKey      INT , ' +
                  '@cActionType    NVARCHAR( 10) , ' +
                  '@cInField04     NVARCHAR( 20) , ' +
                  '@cInField06     NVARCHAR( 20) , ' +
                  '@cInField08     NVARCHAR( 20) , ' +
                  '@cInField10     NVARCHAR( 20) , ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  GOTO Step_1_Fail
               END
            END
         END
      END

      IF @cActionType = 12
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.rdtSTDEventLog WITH (NOLOCK)
                        WHERE EventType = 9 AND ActionType = 12 -- @cActionType -- 12
                        AND ContainerNo = CASE WHEN RTRIM(@cContainerNo) = '' THEN RTRIM(@cAppointmentNo) ELSE RTRIM(@cContainerNo) END) -- INC0527496
         BEGIN
            IF @cExtendedUpdateSP  = ''
            BEGIN
               IF @nMenu = 55
               BEGIN
                  SET @cMenuType = 'I'
               END
               ELSE IF @nMenu = 56
               BEGIN
                  SET @cMenuType = 'O'
               END

               EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '12', -- Check IN
                     @cUserID       = @cUserName,
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = '',
                     @cContainerNo  = @cRefNo1, -- INC0527496
                     @cRefNo4       = @cMenuType,
                     @nStep         = @nStep

               SET @nErrNo = 67942
               SET @cErrMsg = rdt.rdtgetmessage( 67942, @cLangCode, 'DSP') -- CheckIn Done
            END
            ELSE
            BEGIN
               IF @cExtendedUpdateSP <> ''
               BEGIN
                  SET @cActionType = '12'

                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
                        ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
                        ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                        '@nMobile        INT, ' +
                        '@nFunc          INT, ' +
                        '@cLangCode      NVARCHAR( 3),  ' +
                        '@nStep          INT, ' +
                        '@cStorerKey     NVARCHAR( 15), ' +
                        '@cContainerNo   NVARCHAR( 20), ' +
                        '@cAppointmentNo NVARCHAR( 20), ' +
                        '@nInputKey      INT , ' +
                        '@cActionType    NVARCHAR( 10) , ' +
                        '@cInField04     NVARCHAR( 20) , ' +
                        '@cInField06     NVARCHAR( 20) , ' +
                        '@cInField08     NVARCHAR( 20) , ' +
                        '@cInField10     NVARCHAR( 20) , ' +
                        '@cOutField01    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField02    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField03    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField04    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField05    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField06    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField07    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField08    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField09    NVARCHAR( 20) OUTPUT, ' +
                        '@cOutField10    NVARCHAR( 20) OUTPUT, ' +
                        '@nErrNo         INT           OUTPUT, ' +
                        '@cErrMsg        NVARCHAR( 20) OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
                        @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
                        @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                     BEGIN
                        GOTO Step_1_Fail
                     END
                  END

                  IF @cOutField03 = ''
                  BEGIN
                     SET @cFieldAttr03 = 'O'
                     SET @cFieldAttr04 = 'O'
                  END

                  IF @cOutField05 = ''
                  BEGIN
                     SET @cFieldAttr05 = 'O'
                     SET @cFieldAttr06 = 'O'
                  END

                  IF @cOutField07 = ''
                  BEGIN
                     SET @cFieldAttr07 = 'O'
                     SET @cFieldAttr08 = 'O'
                  END

                  IF @cOutField09 = ''
                  BEGIN
                     SET @cFieldAttr09 = 'O'
                     SET @cFieldAttr10 = 'O'
                  END

                  -- Screen mapping
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  --GOTO QUIT
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 67949
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CheckInDoneBefore
            GOTO Step_1_Fail
         END
        
         --(cc02)
         IF @cOTMITF  = '1'
         BEGIN
            SELECT TOP 1 @cMBOLKey = MbolKey FROM dbo.Booking_Out WITH (NOLOCK) WHERE BookingNo = @cAppointmentNo OR altreference = @cAppointmentNo
        	   
            --INSERT INTO traceInfo (TraceName,col1,col2)
            --VALUES ('ccDriver',@cMBOLKey,@cAppointmentNo)         
            
            EXEC ispGenOTMLog 'OTMGateIn', @cMBOLKey, '', @cStorerKey, ''   
            , @b_success OUTPUT   
            , @nErrNo OUTPUT   
            , @cErrMsg OUTPUT    
                                  
            IF @b_success <> 1        
            BEGIN    
               SET @nErrNo = 67950        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenOTMLogFail    
               GOTO Step_1_Fail  
            END   
         END
      END

      IF @cActionType = 22
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM RDT.rdtSTDEventLog WITH (NOLOCK)
                        WHERE EventType = 9 AND ActionType = 22 --@cActionType -- CheckOut
                        AND ContainerNo = CASE WHEN RTRIM(@cContainerNo) = '' THEN RTRIM(@cAppointmentNo) ELSE RTRIM(@cContainerNo) END) -- INC0527496
         BEGIN
            IF @cExtendedUpdateSP <> ''
            BEGIN
               SET @cActionType = '22'

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
                     ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
                     ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3),  ' +
                     '@nStep          INT, ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cContainerNo   NVARCHAR( 20), ' +
                     '@cAppointmentNo NVARCHAR( 20), ' +
                     '@nInputKey      INT , ' +
                     '@cActionType    NVARCHAR( 10) , ' +
                     '@cInField04     NVARCHAR( 20) , ' +
                     '@cInField06     NVARCHAR( 20) , ' +
                     '@cInField08     NVARCHAR( 20) , ' +
                     '@cInField10     NVARCHAR( 20) , ' +
                     '@cOutField01    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField02    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField03    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField04    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField05    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField06    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField07    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField08    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField09    NVARCHAR( 20) OUTPUT, ' +
                     '@cOutField10    NVARCHAR( 20) OUTPUT, ' +
                     '@nErrNo         INT           OUTPUT, ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
                     @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
                     @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     GOTO Step_1_Fail
                  END
               END

               IF @cOutField03 = ''
               BEGIN
                  SET @cFieldAttr03 = 'O'
                  SET @cFieldAttr04 = 'O'
               END

               IF @cOutField05 = ''
               BEGIN
                  SET @cFieldAttr05 = 'O'
                  SET @cFieldAttr06 = 'O'
               END

               IF @cOutField07 = ''
               BEGIN
                  SET @cFieldAttr07 = 'O'
                  SET @cFieldAttr08 = 'O'
               END

               IF @cOutField09 = ''
               BEGIN
                  SET @cFieldAttr09 = 'O'
                  SET @cFieldAttr10 = 'O'
               END

               -- Screen mapping
               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1

               --GOTO QUIT
            END
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = @cActionType, -- '22', -- Check IN
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = '',
                  @cContainerNo  = @cRefNo1, -- INC0527496
                  @cRefNo4       = '',
                  @nStep         = @nStep
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 67943
            SET @cErrMsg = rdt.rdtgetmessage( 67943, @cLangCode, 'DSP') -- Container Exists
            GOTO Step_1_Fail
         END
         
         --(cc02)
         IF @cOTMITF  = '1'
         BEGIN
            SELECT TOP 1 @cMBOLKey = MbolKey FROM dbo.Booking_Out WITH (NOLOCK) WHERE BookingNo = @cAppointmentNo OR altreference = @cAppointmentNo
                     
            EXEC ispGenOTMLog 'OTMGateOut', @cMBOLKey, '', @cStorerKey, ''   
            , @b_success OUTPUT   
            , @nErrNo OUTPUT   
            , @cErrMsg OUTPUT    
                                  
            IF @b_success <> 1        
            BEGIN    
               SET @nErrNo = 67951        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenOTMLogFail    
               GOTO Step_1_Fail  
            END   
         END
      END

      -- Screen mapping
      SET @nScn = @nScn
      SET @nStep = @nStep
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare screen var
      SET @cOutField01 = ''
      SET @cContainerNo = ''

      IF @nMenu = 55
      BEGIN
        SET @cMenuType = 'I'
      END
      ELSE IF @nMenu = 56
      BEGIN
        SET @cMenuType = 'O'
      END

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Sign Out Function
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = '',
         @cRefNo4       = @cMenuType,
         @nStep         = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01  = ''
      SET @cOutField02  = ''
      SET @cOutField03  = ''
      SET @cContainerNo = ''

      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor
   END
 END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2135.

********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = '1' --ENTER
   BEGIN
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cContainerNo   NVARCHAR( 20), ' +
               '@cAppointmentNo NVARCHAR( 20), ' +
               '@nInputKey      INT , ' +
               '@cActionType    NVARCHAR( 10) , ' +
               '@cInField04     NVARCHAR( 20) , ' +
               '@cInField06     NVARCHAR( 20) , ' +
               '@cInField08     NVARCHAR( 20) , ' +
               '@cInField10     NVARCHAR( 20) , ' +
               '@cOutField01    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField02    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField03    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField04    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField05    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField06    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField07    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField08    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField09    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField10    NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO QUIT
            END

            IF @cOutField03 = ''
            BEGIN
               SET @cFieldAttr03 = 'O'
               SET @cFieldAttr04 = 'O'
            END

            IF @cOutField05 = ''
            BEGIN
               SET @cFieldAttr05 = 'O'
               SET @cFieldAttr06 = 'O'
            END

            IF @cOutField07 = ''
            BEGIN
               SET @cFieldAttr07 = 'O'
               SET @cFieldAttr08 = 'O'
            END

            IF @cOutField09 = ''
            BEGIN
               SET @cFieldAttr09 = 'O'
               SET @cFieldAttr10 = 'O'
            END
         END
      END

      --SET @cOutField01 = ''
      --SET @cOutField02 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0   --ESC
   BEGIN
      -- Screen mapping
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END -- Inputkey = 1
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 2136.

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cInput01        = ISNULL(RTRIM(@cInField04),'')
      SET @cInput02        = ISNULL(RTRIM(@cInField06),'')
      SET @cInput03        = ISNULL(RTRIM(@cInField08),'')
      SET @cInput04        = ISNULL(RTRIM(@cInField10),'')
      SET @cOption         = ISNULL(RTRIM(@cInField11),'')

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 67947
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OptionReq
         GOTO Step_3_Fail
      END

      IF ISNULL(RTRIM(@cOption), '') NOT IN ( '1' , '9' )
      BEGIN
         SET @nErrNo = 67948
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidOption
         GOTO Step_3_Fail
      END

      IF ISNULL(RTRIM(@cOption), '') = '1'
      BEGIN
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
                  ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
                  ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cContainerNo   NVARCHAR( 20), ' +
                  '@cAppointmentNo NVARCHAR( 20), ' +
                  '@nInputKey      INT , ' +
                  '@cActionType    NVARCHAR( 10) , ' +
                  '@cInField04     NVARCHAR( 20) , ' +
                  '@cInField06     NVARCHAR( 20) , ' +
                  '@cInField08     NVARCHAR( 20) , ' +
                  '@cInField10     NVARCHAR( 20) , ' +
                  '@cOutField01    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField02    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField03    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField04    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField05    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField06    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField07    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField08    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField09    NVARCHAR( 20) OUTPUT, ' +
                  '@cOutField10    NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
                  @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
                  @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  GOTO Step_3_Fail
               END
            END
         END
      END

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = @cDefaultOption

      -- Screen mapping
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cContainerNo   NVARCHAR( 20), ' +
               '@cAppointmentNo NVARCHAR( 20), ' +
               '@nInputKey      INT , ' +
               '@cActionType    NVARCHAR( 10) , ' +
               '@cInField04     NVARCHAR( 20) , ' +
               '@cInField06     NVARCHAR( 20) , ' +
               '@cInField08     NVARCHAR( 20) , ' +
               '@cInField10     NVARCHAR( 20) , ' +
               '@cOutField01    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField02    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField03    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField04    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField05    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField06    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField07    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField08    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField09    NVARCHAR( 20) OUTPUT, ' +
               '@cOutField10    NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cContainerNo, @cAppointmentNo, @nInputKey, @cActionType, @cInField04, @cInField06, @cInField08, @cInField10,
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT,
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_3_Fail
            END
         END

         IF @cOutField03 = ''
         BEGIN
            SET @cFieldAttr03 = 'O'
            SET @cFieldAttr04 = 'O'
         END

         IF @cOutField05 = ''
         BEGIN
            SET @cFieldAttr05 = 'O'
            SET @cFieldAttr06 = 'O'
         END

         IF @cOutField07 = ''
         BEGIN
            SET @cFieldAttr07 = 'O'
            SET @cFieldAttr08 = 'O'
         END

         IF @cOutField09 = ''
         BEGIN
            SET @cFieldAttr09 = 'O'
            SET @cFieldAttr10 = 'O'
         END
      END

      -- Screen mapping
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   STEP_3_FAIL:
   BEGIN
--      SET @cOutField04 = ''
--      SET @cOutField06 = ''
--      SET @cOutField08 = ''
--      SET @cOutField10 = ''
      SET @cOutField11 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO QUIT

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

      V_String1      = @cContainerNo,
      V_String2      = @cAppointmentNo,
      V_String3      = @cExtendedUpdateSP,
      V_String4      = @cExtendedValidateSP,  --(cc01)

      V_String8      = @cActionType,
      V_String9      = @cRefNo1,
      V_String10     = @cDefaultOption,
      V_String11     = @cDefaultCursor,
      V_String12     = @cOTMITF,  --(cc02)

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
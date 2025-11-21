SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PickSlipNo_Tracking                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Track the time and date of Pick done                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2010-02-18   1.0  Vicky      Created                                 */
/* 2014-06-12   1.1  James      Change function id due to conflict with */
/*                              other module (james01)                  */
/* 2016-10-05   1.2  James      Perf tuning                             */
/* 2017-02-16   1.3  ChewKP     WMS-2162 Modification for other key of  */
/*                              tracking (ChewKP01)                     */
/* 2018-10-05   1.4  Gan        Performance tuning                      */
/* 2020-10-13   1.5  YeeKung    WMS-15497 Change listname rdtevent to   */
/*                              rdtevent01 (yeekung01)                  */
/************************************************************************/
CREATE  PROC [RDT].[rdtfnc_PickSlipNo_Tracking] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
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

   @cSourceKey         NVARCHAR( 20), 
   @cUserID             NVARCHAR( 18), 
   @cClickCnt           NVARCHAR(  1),

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),
   @cColumnName         NVARCHAR(20), -- (ChewKP01) 
   @cEventCode	   		  NVARCHAR(20), -- (ChewKP01) 
   @cColumnName2        NVARCHAR(20), -- (ChewKP01) 
   @cRetainValue        NVARCHAR(5) , -- (ChewKP01) 
   @cColumnName3				NVARCHAR(20), -- (ChewKP01) 
   @cEventCode2					NVARCHAR(20), -- (ChewKP01) 
   @cExtendedValidateSP NVARCHAR(30), -- (ChewKP01)   
   @cExtendedUpdateSP NVARCHAR(30), -- (ChewKP01) 
   @cSQL                NVARCHAR(1000), -- (ChewKP01)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
   @nCursor             INT, -- (ChewKP01) 
      
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


   @cSourceKey     = V_String1,
   @cColumnName    = V_String2, 
   @cColumnName2   = V_String3,
   @cRetainValue   = V_String4, 
   @cColumnName3   = V_String5, 
   @cExtendedValidateSP = V_String6,
   @cExtendedUpdateSP = V_String7,

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
   @nStep_1          = 1,  @nScn_1          = 2240


IF @nFunc = 859   -- (james01)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 859
   IF @nStep = 1  GOTO Step_1           -- Scn = 2240. PickSlipNo
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 859
********************************************************************************/
Step_Start:
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


  EXEC RDT.rdt_STD_EventLog
     @cActionType   = '1', -- Sign In Function
     @cUserID       = @cUserName,
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = @cStorerKey,
     @nStep         = @nStep

   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
      
   -- Prepare label screen var
   SET @cOutField02 = ''
   
   
   SELECT @cColumnName = UDF01
   	     ,@cColumnName2 = UDF02
   	     ,@cColumnName3 = UDF03
         ,@cRetainValue = Short 
   FROM dbo.CodeLkup WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND ListName = 'RDTEVENT01' 
   
   IF ISNULL(@cColumnName,'' ) = '' 
   BEGIN
      SET @cOutField01 = 'PickSlipNo:'
   END
   ELSE 
   BEGIN
      SET @cOutField01 = @cColumnName
   END
   
   IF ISNULL(@cColumnName2,'' ) = '' 
   BEGIN
   		SET @cFieldAttr04 = 'O'
   		SET @cOutField03  = ''
   		SET @cOutField04  = ''
 	 END
 	 ELSE
 	 BEGIN
 	 		SET @cFieldAttr04 = ''
   		SET @cOutField03  = @cColumnName2
   		
 			SET @cOutField04 = ''
   END
   
   IF ISNULL(@cColumnName3,'' ) = '' 
   BEGIN
   		SET @cFieldAttr06 = 'O'
   		SET @cOutField05  = ''
   		SET @cOutField06  = ''
 	 END
 	 ELSE
 	 BEGIN
 	 		SET @cFieldAttr06 = ''
   		SET @cOutField05  = @cColumnName3
   		
 			SET @cOutField06 = ''
   END
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
       SET @cExtendedValidateSP = ''
   END
   
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
Scn = 2137. PickSlip # screen
   PICKSLIPNO       (field01)
***********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

     -- Screen mapping
     SET @cSourceKey = RTRIM(@cInField02) -- (ChewKP01) 
     SET @cEventCode = RTRIM(@cInField04) -- (ChewKP01) 
     SET @cEventCode2 = RTRIM(@cInField06) -- (ChewKP01) 

     --SET @cSourceKey = 'MY0001' 
     --SET @cEventCode = 'WMS_RECEIVE'
     --SET @cEventCode2 = 'SF'

     IF ISNULL(RTRIM(@cSourceKey), '') = '' -- (ChewKP01) 
     BEGIN
         SET @nErrNo = 60981
         SET @cErrMsg = rdt.rdtgetmessage( 60981, @cLangCode, 'DSP') -- PickSlipNo Req
         GOTO Step_1_Fail
     END
     
     
	  IF @cExtendedValidateSP <> ''
     BEGIN                
        IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
        BEGIN 
           SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
              ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cSourceKey, @cEventCode, @cEventCode2, @nCursor OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
           SET @cSQLParam =
              '@nMobile        INT, ' +
              '@nFunc          INT, ' +
              '@cLangCode      NVARCHAR( 3),  ' +
              '@cUserName      NVARCHAR( 18), ' +
              '@cFacility      NVARCHAR( 5),  ' +
              '@cStorerKey     NVARCHAR( 15), ' +
              '@nStep          INT,           ' +
              '@cSourceKey     NVARCHAR( 20), ' +
              '@cEventCode     NVARCHAR( 20), ' +
              '@cEventCode2    NVARCHAR( 20), ' +          
              '@nCursor        INT         OUTPUT, ' +          
              '@nErrNo         INT         OUTPUT, ' + 
              '@cErrMsg        NVARCHAR( 20) OUTPUT'

           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cSourceKey, @cEventCode, @cEventCode2, @nCursor OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
     
           IF @nErrNo <> 0 
           BEGIN
               SET @nErrNo = @nErrNo
         		SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 

               
               IF @nCursor = 2 
               BEGIN
                  SET @cSourceKey = ''
               END
               ELSE IF @nCursor = 4 
               BEGIN
                  SET @cEventCode = ''
               END
               ELSE IF @nCursor = 6 
               BEGIN
                  SET @cEventCode2 = ''
               END 

               EXEC rdt.rdtSetFocusField @nMobile, @nCursor

         		GOTO Step_1_Fail
           END
        END
     END 	
     
     

    
    
     IF @cExtendedUpdateSP <> ''
     BEGIN                
        IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
        BEGIN 
           SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
              ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cSourceKey, @cEventCode, @cEventCode2, @nErrNo OUTPUT, @cErrMsg OUTPUT '
           SET @cSQLParam =
              '@nMobile        INT, ' +
              '@nFunc          INT, ' +
              '@cLangCode      NVARCHAR( 3),  ' +
              '@cUserName      NVARCHAR( 18), ' +
              '@cFacility      NVARCHAR( 5),  ' +
              '@cStorerKey     NVARCHAR( 15), ' +
              '@nStep          INT,           ' +
              '@cSourceKey     NVARCHAR( 20), ' +
              '@cEventCode 	 NVARCHAR( 20), ' +
              '@cEventCode2    NVARCHAR( 20), ' +          
              '@nErrNo         INT         OUTPUT, ' + 
              '@cErrMsg        NVARCHAR( 20) OUTPUT'

           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @nStep, @cSourceKey, @cEventCode, @cEventCode2, @nErrNo OUTPUT, @cErrMsg OUTPUT 
     
           IF @nErrNo <> 0 
           BEGIN
               SET @nErrNo = @nErrNo
         		SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 

         		GOTO Step_1_Fail
           END
        END
     END 
     ELSE
     BEGIN
      
       EXEC RDT.rdt_STD_EventLog
         @cActionType   = '14',
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cSourceKey    = @cSourceKey,
         --@cEventCode    = @cEventCode,
        -- @cEventCode2   = @cEventCode2,

         --@cRefNo1       = @cSourceKey, -- (ChewKP01) 
    	   @cRefNo2       = @cEventCode, -- (ChewKP01) 
    		@cRefNo3       = @cEventCode2, -- (ChewKP01)
    		@nStep         = @nStep
    		
     END	

     
     --SET @nErrNo = 60982
     --SET @cErrMsg = rdt.rdtgetmessage( 60982, @cLangCode, 'DSP') -- Scan Done

     

     -- Screen mapping
     SET @cOutField01 = @cColumnName
     SET @cOutField03 = @cColumnName2
     SET @cOutField05 = @cColumnName3

     IF CHARINDEX ( '2', @cRetainValue ) > 0 
      SET @cOutField02 = @cSourceKey
     ELSE
      SET @cOutField02 = ''

     IF CHARINDEX ( '4', @cRetainValue ) > 0 
      SET @cOutField04 = @cEventCode
     ELSE
      SET @cOutField04 = ''
      
     IF CHARINDEX ( '6', @cRetainValue ) > 0 
      SET @cOutField06 = @cEventCode2
     ELSE
      SET @cOutField06 = ''
     
     
     
     SET @nScn = @nScn
     SET @nStep = @nStep
     
     EXEC rdt.rdtSetFocusField @nMobile, 6
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare screen var
      SET @cOutField01 = '' 
      SET @cSourceKey = ''


      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Sign Out Function
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
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
      SET @cOutField01 = @cColumnName
      SET @cOutField02 = @cSourceKey
      SET @cOutField04 = @cEventCode
      SET @cOutField06 = @cEventCode2
      --SET @cSourceKey = ''
      --EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
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
      --UserName       = @cUserName,
      

      V_String1      = @cSourceKey,
      V_String2      = @cColumnName, 
      V_String3      = @cColumnName2,
      V_String4      = @cRetainValue,
      V_String5      = @cColumnName3,
      V_String6		= @cExtendedValidateSP, 
      V_String7      = @cExtendedUpdateSP,
     
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
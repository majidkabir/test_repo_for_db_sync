SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_Marshalling                                       */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#151573                                                       */
/*          Related Module: RDT Scan To Van                                  */
/*                          RDT Seal Van                                     */
/*                          RDT Tote Inquiry                                 */ 
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-10-27 1.0  Vicky    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-11-02 1.2  Gan      Performance tuning                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Marshalling](
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
   @cActStoreNo         NVARCHAR(10),

   @nRowRef             INT,
   @nRowCnt             INT,
   @nPIKNo              INT,
   @nToteNo             INT,

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),


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
   
   @nPIKNo           = V_Integer1,
   @nToteNo          = V_Integer2,

   @cToteNo          = V_String1,
   @cStoreNo         = V_String2,  
   @cActStoreNo      = V_String3,  
  -- @nPIKNo           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,   
  -- @nToteNo          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
      
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
IF @nFunc = 1633
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1633
   IF @nStep = 1 GOTO Step_1   -- Scn = 2150   Tote#
   IF @nStep = 2 GOTO Step_2   -- Scn = 2151   Tote#, Store#
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1900)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2150
   SET @nStep = 1

   
   -- initialise all variable
   SET @cToteNo = ''
   SET @cStoreNo = ''
   SET @cActStoreNo = ''
   SET @nPIKNo = 0
   SET @nToteNo = 0

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2150
   Tote # (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToteNo = @cInField01

      --When Tote# is blank
      IF @cToteNo = ''
      BEGIN
--         SET @nErrNo = 68216
--         SET @cErrMsg = rdt.rdtgetmessage( 68216, @cLangCode, 'DSP') --Tote# req
--         GOTO Step_1_Fail  

         SET @nErrNo = 0
         SET @cErrMsg1 = '68216'
         SET @cErrMsg2 = 'TOTE# Req'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         SET @cOutField01 = ''
         SET @cToteNo = ''
         GOTO Quit         
      END 

      IF ISNUMERIC(@cToteNo) = 0
      BEGIN
--         SET @nErrNo = 68224
--         SET @cErrMsg = rdt.rdtgetmessage( 68224, @cLangCode, 'DSP') --ToteNotNum
--         GOTO Step_1_Fail  

         SET @nErrNo = 0
         SET @cErrMsg1 = '68224'
         SET @cErrMsg2 = 'Tote Not'
         SET @cErrMsg3 = 'Numeric'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cToteNo = ''
         GOTO Quit    
      END
     
      SET @nToteNo = CAST(@cToteNo AS INT)

      -- Check if Tote# exists
      IF NOT EXISTS ( SELECT 1 
         FROM rdt.rdtToteInfoLog WITH (NOLOCK)
         WHERE ToteNo = @nToteNo)
      BEGIN
--         SET @nErrNo = 68217
--         SET @cErrMsg = rdt.rdtgetmessage( 68217, @cLangCode, 'DSP') --Invalid Tote#
--         GOTO Step_1_Fail    

         SET @nErrNo = 0
         SET @cErrMsg1 = '68217'
         SET @cErrMsg2 = 'Invalid Tote#'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         SET @cOutField01 = ''
         SET @cToteNo = ''
         GOTO Quit    
      END

      -- Get latest Tote if Tote # - Uniqueness is PIKNo + Store + ToteNo
      SELECT TOP 1 @nPIKNo = PIKNo,
                   @cActStoreNo = RTRIM(Store)
      FROM rdt.rdtToteInfoLog WITH (NOLOCK)
      WHERE ToteNo = @nToteNo
      ORDER BY ToteDate DESC

      -- Check if Tote# marshalled
      -- 0 = Interfaced, 2 = Marshalled, 7 = Scanned, 8 = Printed, 9 = Shipped
      IF EXISTS ( SELECT 1 
                  FROM rdt.rdtToteInfoLog WITH (NOLOCK)
                  WHERE ToteNo = @nToteNo
                  AND   PIKNo = @nPIKNo
                  AND   Store = @cActStoreNo
                  AND   Status >= '2')
      BEGIN
--         SET @nErrNo = 68218
--         SET @cErrMsg = rdt.rdtgetmessage( 68218, @cLangCode, 'DSP') --Tote Marshalled
--         GOTO Step_1_Fail    

         SET @nErrNo = 0
         SET @cErrMsg1 = '68218'
         SET @cErrMsg2 = 'Tote'
         SET @cErrMsg3 = 'Marshalled'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cToteNo = ''
         GOTO Quit    
      END

      -- Check if Trailer # empty
      IF EXISTS ( SELECT 1 
                  FROM rdt.rdtToteInfoLog WITH (NOLOCK)
                  WHERE ToteNo = @nToteNo
                  AND   PIKNo = @nPIKNo
                  AND   Store = @cActStoreNo
                  AND   ISNULL(RTRIM(Trailer), '') <> '')
      BEGIN
--         SET @nErrNo = 68219
--         SET @cErrMsg = rdt.rdtgetmessage( 68219, @cLangCode, 'DSP') --Already Loaded
--         GOTO Step_1_Fail    

         SET @nErrNo = 0
         SET @cErrMsg1 = '68219'
         SET @cErrMsg2 = 'Tote Already'
         SET @cErrMsg3 = 'Loaded'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cToteNo = ''
         GOTO Quit    
      END
      
              
      --prepare next screen variable
      SET @cOutField01 = @cToteNo
      SET @cOutField02 = ''
                        
      -- Go to next screen
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

      SET @cToteNo = ''
      SET @cStoreNo = ''
      SET @cActStoreNo = ''
      SET @nPIKNo = 0
      SET @nToteNo = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @nToteNo = 0
      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2151) 
   Tote #: (Field01)
   Store #: (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cStoreNo = @cInField02
      
      --When StoreNo is blank
      IF @cStoreNo = ''
      BEGIN
--         SET @nErrNo = 68220
--         SET @cErrMsg = rdt.rdtgetmessage( 68220, @cLangCode, 'DSP') --Store# req
--         EXEC rdt.rdtSetFocusField @nMobile, 2
--         GOTO Step_2_Fail  

         SET @nErrNo = 0
         SET @cErrMsg1 = '68220'
         SET @cErrMsg2 = 'Store #'
         SET @cErrMsg3 = 'Required'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = ''
         SET @cStoreNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit    
      END 

      --Check If Store exists
      IF NOT EXISTS (SELECT 1 
                     FROM rdt.rdtToteInfoLog WITH (NOLOCK)
                     WHERE ToteNo = @nToteNo
                     AND   PIKNo = @nPIKNo
                     AND   Store = @cStoreNo)
       BEGIN
--         SET @nErrNo = 68221
--         SET @cErrMsg = rdt.rdtgetmessage( 68221, @cLangCode, 'DSP') --ToteNotForStore
--         EXEC rdt.rdtSetFocusField @nMobile, 2
--         GOTO Step_2_Fail    

         SET @nErrNo = 0
         SET @cErrMsg1 = '68221'
         SET @cErrMsg2 = 'Tote Not'
         SET @cErrMsg3 = 'For Store'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = ''
         SET @cStoreNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit   
       END

      -- Check if Store the same as Actual Store
       IF @cStoreNo <> @cActStoreNo
       BEGIN
--         SET @nErrNo = 68222
--         SET @cErrMsg = rdt.rdtgetmessage( 68222, @cLangCode, 'DSP') --ToteNotForStore
--         EXEC rdt.rdtSetFocusField @nMobile, 2
--         GOTO Step_2_Fail    

         SET @nErrNo = 0
         SET @cErrMsg1 = '68222'
         SET @cErrMsg2 = 'Tote Not'
         SET @cErrMsg3 = 'For Store'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = ''
         SET @cStoreNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit  
       END

     
       -- Update table
       UPDATE RDT.rdtToteInfoLog WITH (ROWLOCK)
           SET Status = '2',
               MarshalDate = GETDATE(),
               MarshalWho = @cUserName
        WHERE PIKNo = @nPIKNo
        AND   Store = @cStoreNo
        AND   ToteNo = @nToteNo
        AND   Status = '0'

        IF @@ERROR <> 0
        BEGIN
           ROLLBACK TRAN

--           SET @nErrNo = 68223
--           SET @cErrMsg = rdt.rdtgetmessage( 68223, @cLangCode, 'DSP') --'UpdateFail'
--           GOTO Step_2_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68223'
             SET @cErrMsg2 = 'Update'
             SET @cErrMsg3 = 'Fail'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = @cToteNo
             SET @cOutField02 = ''
             SET @cStoreNo = ''
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Quit  
        END
        COMMIT TRAN
 
        --prepare next screen variable
        SET @cOutField01 = ''
        SET @cOutField02 = ''

        SET @cToteNo = ''
        SET @cStoreNo = ''
        SET @cActStoreNo = ''
        SET @nPIKNo = 0
        SET @nToteNo = 0
                            
        -- Go next screen
        SET @nScn = @nScn - 1
        SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
          --prepare prev screen variable
          SET @cOutField01 = ''
          SET @cOutField02 = ''

          SET @cToteNo = ''
          SET @cStoreNo = ''
          SET @cActStoreNo = ''
          SET @nPIKNo = 0
          SET @nToteNo = 0

          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cStoreNo = ''
      
      -- Reset this screen var
      SET @cOutField01 = @cToteNo
      SET @cOutField02 = ''
  END
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
       
       V_Integer1    = @nPIKNo,
       V_Integer2    = @nToteNo,

       V_String1     = @cToteNo,
       V_String2     = @cStoreNo,    
       V_String3     = @cActStoreNo,    
       --V_String4     = @nPIKNo, 
       --V_String5     = @nToteNo,

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
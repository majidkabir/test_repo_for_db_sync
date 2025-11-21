SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_Seal_Van                                          */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#151573                                                       */
/*          Related Module: RDT Marshalling                                  */
/*                          RDT Scan To Van                                  */
/*                          RDT Tote Inquiry                                 */ 
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-10-27 1.0  Vicky    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Seal_Van](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 250)
        
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

   @cTrailerID          NVARCHAR(10),
   @cToteCnt            NVARCHAR(10),
   @cManifestNo         NVARCHAR(10),
   @cSealOption         NVARCHAR(1),
   @cPrintOption        NVARCHAR(1),
   @cReprintOption      NVARCHAR(1),

   @cDataWindow         NVARCHAR(50), 
   @cTargetDB           NVARCHAR(10), 

   @nToteCnt            INT,
   @nManifestCnt        INT,
   @nManifestNo         INT,

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

   @cTrailerID       = V_String1,  
   @cToteCnt         = V_String2,
   @cSealOption      = V_String3,
   @cPrintOption     = V_String4,
   @cReprintOption   = V_String5,
   @cManifestNo      = V_String6,
      
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
IF @nFunc = 1635
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1635
   IF @nStep = 1 GOTO Step_1   -- Scn = 2170   TRLR ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2171   TRLR ID, Seal Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 2172   TRLR ID, Print M'fest
   IF @nStep = 4 GOTO Step_4   -- Scn = 2173   Re-Print M'fest
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1635)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2170
   SET @nStep = 1

   
   -- initialise all variable
   SET @cTrailerID = ''
   SET @cSealOption = ''
   SET @cPrintOption = ''
   SET @cReprintOption = ''
   SET @cManifestNo = ''
   SET @cToteCnt = '0'
   SET @nToteCnt = 0

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2170
   TRLR ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTrailerID = @cInField01

      --When TrailerID is blank
      IF @cTrailerID = ''
      BEGIN
--         SET @nErrNo = 68316
--         SET @cErrMsg = rdt.rdtgetmessage( 68316, @cLangCode, 'DSP') --TRLR req
--         GOTO Step_1_Fail  

         SET @nErrNo = 0
         SET @cErrMsg1 = '68316'
         SET @cErrMsg2 = 'Trailer'
         SET @cErrMsg3 = 'Required'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cTrailerID = ''
         GOTO Quit     
      END 

      --Check if TrailerID exists
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtToteInfoLog WITH (NOLOCK)
                     WHERE Trailer = @cTrailerID)
      BEGIN
--         SET @nErrNo = 68317
--         SET @cErrMsg = rdt.rdtgetmessage( 68317, @cLangCode, 'DSP') --Invalid TRLR
--         GOTO Step_1_Fail  

         SET @nErrNo = 0
         SET @cErrMsg1 = '68317'
         SET @cErrMsg2 = 'Invalid'
         SET @cErrMsg3 = 'Trailer'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = ''
         SET @cTrailerID = ''
         GOTO Quit   
      END 
              
      --prepare next screen variable
      SET @cOutField01 = @cTrailerID
      SET @cOutField02 = '5' -- Default as 5
                        
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
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = ''

      SET @cTrailerID = ''
      SET @cSealOption = ''
      SET @cPrintOption = ''
      SET @cReprintOption = ''
      SET @cManifestNo = ''
      SET @cToteCnt = '0'
      SET @nToteCnt = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cTrailerID = ''
      SET @cOutField01 = ''
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2171) 
   TRLR ID: (Field01)
   Seal Option: (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSealOption = @cInField02
      
      -- Validate blank
      IF ISNULL(RTRIM(@cSealOption), '') = ''
      BEGIN
--        SET @nErrNo = 68318
--        SET @cErrMsg = rdt.rdtgetmessage( 68318, @cLangCode, 'DSP') --Option needed
--        GOTO Step_2_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68318'
         SET @cErrMsg2 = 'Option'
         SET @cErrMsg3 = 'Needed'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cTrailerID
         SET @cOutField02 = '5'
         SET @cSealOption = ''
         GOTO Quit   
      END

      -- Validate option
      IF (@cSealOption <> '1' AND @cSealOption <> '5')
      BEGIN
--        SET @nErrNo = 68319
--        SET @cErrMsg = rdt.rdtgetmessage( 68319, @cLangCode, 'DSP') --Invalid option
--        GOTO Step_2_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68319'
         SET @cErrMsg2 = 'Invalid'
         SET @cErrMsg3 = 'Option'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cTrailerID
         SET @cOutField02 = '5'
         SET @cSealOption = ''
         GOTO Quit   
      END

     
     IF @cSealOption = '1'
     BEGIN
       -- Check whether manifest # is blank
       SELECT @nManifestCnt = COUNT(DISTINCT ManifestNo)
       FROM rdt.rdtToteInfoLog WITH (NOLOCK)
       WHERE Trailer = @cTrailerID

       IF @nManifestCnt > 1
       BEGIN
          --  SET @nErrNo = 68320
          --  SET @cErrMsg = rdt.rdtgetmessage( 68320, @cLangCode, 'DSP') -- '>1 MFEST#
          SET @cOutField05 = '68320 >1 MFEST#'
       END

       SELECT DISTINCT @cManifestNo = RTRIM(ManifestNo)
       FROM rdt.rdtToteInfoLog WITH (NOLOCK)
       WHERE Trailer = @cTrailerID

       IF ISNULL(RTRIM(@cManifestNo), '') <> ''
       BEGIN
--            SET @nErrNo = 68321
--            SET @cErrMsg = rdt.rdtgetmessage( 68321, @cLangCode, 'DSP') --Alrdy Sealed
          SET @cOutField05 = '68321 Alrdy Sealed'
       END

       -- Total of Tote for Trailer
       SELECT @nToteCnt = COUNT(DISTINCT ToteNo)
       FROM rdt.rdtToteInfoLog WITH (NOLOCK)
       WHERE Trailer = @cTrailerID
    
       SELECT @cToteCnt = CAST(@nToteCnt AS CHAR)

       --prepare next screen variable
       SET @cOutField01 = @cTrailerID
       SET @cOutField02 = RTRIM(@cToteCnt)
       SET @cOutField03 = '5'
                       
       -- Go next screen
       SET @nScn = @nScn + 1
       SET @nStep = @nStep + 1

     END
     ELSE
     BEGIN
          --prepare prev screen variable
          SET @cOutField01 = ''
          SET @cOutField02 = ''
          SET @cOutField03 = ''
          SET @cOutField04 = ''
          SET @cOutField05 = ''

          SET @cTrailerID = ''
          SET @cSealOption = ''
          SET @cManifestNo = ''
                            
          -- Go prev screen
          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1
     END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
          --prepare prev screen variable
          SET @cOutField01 = ''
          SET @cOutField02 = ''
          SET @cOutField03 = '' 
          SET @cOutField04 = '' 
          SET @cOutField05 = ''

          SET @cTrailerID = ''
          SET @cSealOption = ''
          SET @cPrintOption = ''
          SET @cManifestNo = ''
          SET @cToteCnt = '0'
          SET @nToteCnt = 0

          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSealOption = ''
      
      -- Reset this screen var
      SET @cOutField01 = @cTrailerID
      SET @cOutField02 = '5'
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2172) 
   TRLR ID: (Field01)
   # TOTE : (Field02)
   Print Option: (Field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPrintOption = @cInField03
      
      -- Validate blank
      IF ISNULL(RTRIM(@cPrintOption), '') = ''
      BEGIN
--        SET @nErrNo = 68322
--        SET @cErrMsg = rdt.rdtgetmessage( 68322, @cLangCode, 'DSP') --Option needed
--        GOTO Step_3_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68322'
         SET @cErrMsg2 = 'Option'
         SET @cErrMsg3 = 'Needed'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cTrailerID
         SET @cOutField02 = @cToteCnt
         SET @cOutField03 = '5'
         SET @cPrintOption = ''
         GOTO Quit   
      END

      -- Validate option
      IF (@cPrintOption <> '1' AND @cPrintOption <> '5')
      BEGIN
--        SET @nErrNo = 68323
--        SET @cErrMsg = rdt.rdtgetmessage( 68323, @cLangCode, 'DSP') --Invalid option
--        GOTO Step_3_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68323'
         SET @cErrMsg2 = 'Invalid'
         SET @cErrMsg3 = 'Option'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cTrailerID
         SET @cOutField02 = @cToteCnt
         SET @cOutField03 = '5'
         SET @cPrintOption = ''
         GOTO Quit   
      END
     
     IF @cPrintOption = '1'
     BEGIN
       IF CAST(@cToteCnt AS INT) = 0
       BEGIN
--        SET @nErrNo = 68324
--        SET @cErrMsg = rdt.rdtgetmessage( 68324, @cLangCode, 'DSP') --NoToteToPrint
--        GOTO Step_3_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68324'
         SET @cErrMsg2 = 'No Tote'
         SET @cErrMsg3 = 'To Print'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = @cTrailerID
         SET @cOutField02 = @cToteCnt
         SET @cOutField03 = '5'
         SET @cPrintOption = ''
         GOTO Quit  
       END
       ELSE
       BEGIN
         IF ISNULL(RTRIM(@cManifestNo), '') <> '' -- Reprint
         BEGIN
            SET @cOutField01 = '5'
            SET @cOutField02 = '' 
            SET @cOutField03 = '' 
            SET @cOutField04 = '' 
            SET @cOutField05 = ''

            -- Go reprint screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
         ELSE
         BEGIN 
            -- Get Manifest # 
            SELECT @b_success=0
            EXECUTE   nspg_getkey
              'SEALMANF'
              , 10
              , @cManifestNo OUTPUT
              , @b_success OUTPUT
              , @n_err OUTPUT
              , @c_errmsg OUTPUT
            IF @b_success=0
            BEGIN
                  ROLLBACK TRAN
--                SET @nErrNo = 68325
--                SET @cErrMsg = rdt.rdtgetmessage( 68325, @cLangCode, 'DSP') -- Manifest#Err
--                GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68325'
                 SET @cErrMsg2 = 'Gen Manifest'
                 SET @cErrMsg3 = 'Num Error'
                 EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                    @cErrMsg1, @cErrMsg2, @cErrMsg3
                 IF @nErrNo = 1
                 BEGIN
                    SET @cErrMsg1 = ''
                    SET @cErrMsg2 = ''
                    SET @cErrMsg3 = ''
                 END
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit  
            END

            SET @nManifestNo = CAST(@cManifestNo AS INT)

            BEGIN TRAN
 
            UPDATE rdt.rdtToteInfoLog WITH (ROWLOCK)
              SET Status = '8',
                  ManifestNo = CAST(@nManifestNo AS CHAR),
                  EditWho = @cUserName,
                  EditDate = GETDATE()
            WHERE Trailer = @cTrailerID
            AND   ISNULL(RTRIM(ManifestNo), '') = ''

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN

--               SET @nErrNo = 68326
--               SET @cErrMsg = rdt.rdtgetmessage( 68326, @cLangCode, 'DSP') --'UpdateFail'
--               GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68326'
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
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit  
            END
            COMMIT TRAN

            -- Print Manifest
            -- Validate printer setup
  		      IF ISNULL(@cPrinter, '') = ''
		      BEGIN			
--	           SET @nErrNo = 68327
--	           SET @cErrMsg = rdt.rdtgetmessage( 68327, @cLangCode, 'DSP') --NoLoginPrinter
--	           GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68327'
                 SET @cErrMsg2 = 'No Login'
                 SET @cErrMsg3 = 'Printer'
                 EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                    @cErrMsg1, @cErrMsg2, @cErrMsg3
                 IF @nErrNo = 1
                 BEGIN
                    SET @cErrMsg1 = ''
                    SET @cErrMsg2 = ''
                    SET @cErrMsg3 = ''
                 END
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit  
		      END
    		       
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
	         FROM RDT.RDTReport WITH (NOLOCK) 
	         WHERE StorerKey = @cStorerKey
            AND   ReportType = 'SEALMANRPT' 
                   	
            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
--               SET @nErrNo = 68328
--               SET @cErrMsg = rdt.rdtgetmessage( 68328, @cLangCode, 'DSP') --DWNOTSetup
--               GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68328'
                 SET @cErrMsg2 = 'Rpt DataWindow'
                 SET @cErrMsg3 = 'Not Setup'
                 EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                    @cErrMsg1, @cErrMsg2, @cErrMsg3
                 IF @nErrNo = 1
                 BEGIN
                    SET @cErrMsg1 = ''
                    SET @cErrMsg2 = ''
                    SET @cErrMsg3 = ''
                 END
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit 
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
--               SET @nErrNo = 68329
--               SET @cErrMsg = rdt.rdtgetmessage( 68329, @cLangCode, 'DSP') --TgetDB Not Set
--               GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68329'
                 SET @cErrMsg2 = 'TargetDB'
                 SET @cErrMsg3 = 'Not Setup'
                 EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                    @cErrMsg1, @cErrMsg2, @cErrMsg3
                 IF @nErrNo = 1
                 BEGIN
                    SET @cErrMsg1 = ''
                    SET @cErrMsg2 = ''
                    SET @cErrMsg3 = ''
                 END
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit 
            END

            BEGIN TRAN

            -- Call printing spooler
            INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
            VALUES('PRINT_MANIFEST', 'SEALMANRPT', '0', @cDataWindow, 2, RTRIM(@cTrailerID), CAST(@nManifestNo AS CHAR), @cPrinter, 1, @nMobile, @cTargetDB) 

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
--
--               SET @nErrNo = 68330
--               SET @cErrMsg = rdt.rdtgetmessage( 68330, @cLangCode, 'DSP') --'InsertPRTFail'
--               GOTO Step_3_Fail

                 SET @nErrNo = 0
                 SET @cErrMsg1 = '68330'
                 SET @cErrMsg2 = 'Insert'
                 SET @cErrMsg3 = 'PrintJob Fail'
                 EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                    @cErrMsg1, @cErrMsg2, @cErrMsg3
                 IF @nErrNo = 1
                 BEGIN
                    SET @cErrMsg1 = ''
                    SET @cErrMsg2 = ''
                    SET @cErrMsg3 = ''
                 END
                 SET @cOutField01 = @cTrailerID
                 SET @cOutField02 = @cToteCnt
                 SET @cOutField03 = '5'
                 SET @cPrintOption = ''
                 GOTO Quit 
            END
            COMMIT TRAN

            --prepare next screen variable
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = '' 
            SET @cOutField05 = ''

            SET @cTrailerID = ''
            SET @cSealOption = ''
            SET @cPrintOption = ''
            SET @cManifestNo = ''
            SET @cToteCnt = '0'
            SET @nToteCnt = 0
                           
            -- Go next screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END -- New Print
       END -- ToteCnt > 0
     END
     ELSE
     BEGIN
       -- Get Manifest # 
        SELECT @b_success=0
        EXECUTE   nspg_getkey
          'SEALMANF'
          , 10
          , @cManifestNo OUTPUT
          , @b_success OUTPUT
          , @n_err OUTPUT
          , @c_errmsg OUTPUT
        IF @b_success=0
        BEGIN
            ROLLBACK TRAN
--            SET @nErrNo = 68325
--            SET @cErrMsg = rdt.rdtgetmessage( 68325, @cLangCode, 'DSP') -- Manifest#Err
--            GOTO Step_3_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68325'
             SET @cErrMsg2 = 'Gen Manifest'
             SET @cErrMsg3 = 'Num Error'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = @cTrailerID
             SET @cOutField02 = @cToteCnt
             SET @cOutField03 = '5'
             SET @cPrintOption = ''
             GOTO Quit 
        END

        SET @nManifestNo = CAST(@cManifestNo AS INT)

        BEGIN TRAN

        UPDATE rdt.rdtToteInfoLog WITH (ROWLOCK)
          SET Status = '8',
              ManifestNo = CAST(@nManifestNo AS CHAR),
              EditWho = @cUserName,
              EditDate = GETDATE()
        WHERE Trailer = @cTrailerID
        AND   ISNULL(RTRIM(ManifestNo), '') = ''

        IF @@ERROR <> 0
        BEGIN
           ROLLBACK TRAN

--           SET @nErrNo = 68326
--           SET @cErrMsg = rdt.rdtgetmessage( 68326, @cLangCode, 'DSP') --'UpdateFail'
--           GOTO Step_3_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68326'
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
             SET @cOutField01 = @cTrailerID
             SET @cOutField02 = @cToteCnt
             SET @cOutField03 = '5'
             SET @cPrintOption = ''
             GOTO Quit 
        END
        COMMIT TRAN

        --prepare next screen variable
        SET @cOutField01 = ''
        SET @cOutField02 = ''
        SET @cOutField03 = ''
        SET @cOutField04 = '' 
        SET @cOutField05 = ''

        SET @cTrailerID = ''
        SET @cSealOption = ''
        SET @cPrintOption = ''
        SET @cManifestNo = ''
        SET @cToteCnt = '0'
        SET @nToteCnt = 0
                       
        -- Go next screen
        SET @nScn = @nScn - 2
        SET @nStep = @nStep - 2
     END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
        --prepare next screen variable
        SET @cOutField01 = ''
        SET @cOutField02 = ''
        SET @cOutField03 = ''
        SET @cOutField04 = '' 
        SET @cOutField05 = ''

        SET @cTrailerID = ''
        SET @cSealOption = ''
        SET @cPrintOption = ''
        SET @cManifestNo = ''
        SET @cToteCnt = '0'
        SET @nToteCnt = 0
                       
        -- Go next screen
        SET @nScn = @nScn - 2
        SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cPrintOption = ''
      
      --reset screen variable
      SET @cOutField01 = @cTrailerID
      SET @cOutField02 = @cToteCnt
      SET @cOutField03 = '5'
      SET @cOutField04 = '' 
      SET @cOutField05 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 2173) 
   Reprint Option: (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReprintOption = @cInField01
      
      -- Validate blank
      IF ISNULL(RTRIM(@cReprintOption), '') = ''
      BEGIN
--        SET @nErrNo = 68331
--        SET @cErrMsg = rdt.rdtgetmessage( 68331, @cLangCode, 'DSP') --Option needed
--        GOTO Step_4_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68331'
             SET @cErrMsg2 = 'Option'
             SET @cErrMsg3 = 'Needed'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = '5'
             SET @cReprintOption = ''
             GOTO Quit 
      END

      -- Validate option
      IF (@cReprintOption <> '1' AND @cReprintOption <> '5')
      BEGIN
--        SET @nErrNo = 68332
--        SET @cErrMsg = rdt.rdtgetmessage( 68332, @cLangCode, 'DSP') --Invalid option
--        GOTO Step_4_Fail

         SET @nErrNo = 0
         SET @cErrMsg1 = '68332'
         SET @cErrMsg2 = 'Invalid'
         SET @cErrMsg3 = 'Option'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         SET @cOutField01 = '5'
         SET @cReprintOption = ''
         GOTO Quit 
      END

      IF @cReprintOption = '1'
      BEGIN
	      IF ISNULL(@cPrinter, '') = ''
	      BEGIN			
--          SET @nErrNo = 68333
--          SET @cErrMsg = rdt.rdtgetmessage( 68333, @cLangCode, 'DSP') --NoLoginPrinter
--          GOTO Step_4_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68333'
             SET @cErrMsg2 = 'No Login'
             SET @cErrMsg3 = 'Printer'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = '5'
             SET @cReprintOption = ''
             GOTO Quit 
	      END
		       
        SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
               @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
        FROM RDT.RDTReport WITH (NOLOCK) 
        WHERE StorerKey = @cStorerKey
        AND   ReportType = 'SEALMANRPT' 
               	
        IF ISNULL(@cDataWindow, '') = ''
        BEGIN
--           SET @nErrNo = 68334
--           SET @cErrMsg = rdt.rdtgetmessage( 68334, @cLangCode, 'DSP') --DWNOTSetup
--           GOTO Step_4_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68334'
             SET @cErrMsg2 = 'Rpt Datawindow'
             SET @cErrMsg3 = 'Not Setup'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = '5'
             SET @cReprintOption = ''
             GOTO Quit 
        END

        IF ISNULL(@cTargetDB, '') = ''
        BEGIN
--           SET @nErrNo = 68335
--           SET @cErrMsg = rdt.rdtgetmessage( 68335, @cLangCode, 'DSP') --TgetDB Not Set
--           GOTO Step_4_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68335'
             SET @cErrMsg2 = 'TargetDB'
             SET @cErrMsg3 = 'Not Setup'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = '5'
             SET @cReprintOption = ''
             GOTO Quit 
        END

        SET @nManifestNo = CAST(@cManifestNo AS INT)

        BEGIN TRAN

        -- Call printing spooler
        INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
        VALUES('REPRINT_MANIFEST', 'SEALMANRPT', '0', @cDataWindow, 2, RTRIM(@cTrailerID), CAST(@nManifestNo AS CHAR), @cPrinter, 1, @nMobile, @cTargetDB) 

        IF @@ERROR <> 0
        BEGIN
           ROLLBACK TRAN

--           SET @nErrNo = 68336
--           SET @cErrMsg = rdt.rdtgetmessage( 68336, @cLangCode, 'DSP') --'InsertPRTFail'
--           GOTO Step_4_Fail

             SET @nErrNo = 0
             SET @cErrMsg1 = '68336'
             SET @cErrMsg2 = 'Insert'
             SET @cErrMsg3 = 'PrintJob Fail'
             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                @cErrMsg1, @cErrMsg2, @cErrMsg3
             IF @nErrNo = 1
             BEGIN
                SET @cErrMsg1 = ''
                SET @cErrMsg2 = ''
                SET @cErrMsg3 = ''
             END
             SET @cOutField01 = '5'
             SET @cReprintOption = ''
             GOTO Quit 
        END
        COMMIT TRAN

        --prepare next screen variable
        SET @cOutField01 = ''
        SET @cOutField02 = ''
        SET @cOutField03 = ''
        SET @cOutField04 = '' 
        SET @cOutField05 = ''

        SET @cTrailerID = ''
        SET @cSealOption = ''
        SET @cPrintOption = ''
        SET @cReprintOption = ''
        SET @cManifestNo = ''
        SET @cToteCnt = '0'
        SET @nToteCnt = 0
                       
        -- Go next screen
        SET @nScn = @nScn - 3
        SET @nStep = @nStep - 3
     END
     ELSE
     BEGIN
          --prepare prev screen variable
          SET @cOutField01 = ''
          SET @cOutField02 = ''
          SET @cOutField03 = ''
          SET @cOutField04 = ''
          SET @cOutField05 = ''

          SET @cTrailerID = ''
          SET @cSealOption = ''
          SET @cManifestNo = ''
                            
          -- Go prev screen
          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1
     END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
          --prepare prev screen variable
          SET @cOutField01 = ''
          SET @cOutField02 = ''
          SET @cOutField03 = ''
          SET @cOutField04 = '' 
          SET @cOutField05 = ''

          SET @cTrailerID = ''
          SET @cSealOption = ''
          SET @cPrintOption = ''
          SET @cReprintOption = ''
          SET @cManifestNo = ''
          SET @cToteCnt = '0'
          SET @nToteCnt = 0

          SET @nScn = @nScn - 3
          SET @nStep = @nStep - 3
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cReprintOption = ''
      
      -- Reset this screen var
      SET @cOutField01 = '5'
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

       V_String1     = @cTrailerID,
       V_String2     = @cToteCnt,
       V_String3     = @cSealOption,
       V_String4     = @cPrintOption,
       V_String5     = @cReprintOption,
       V_String6     = @cManifestNo,

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
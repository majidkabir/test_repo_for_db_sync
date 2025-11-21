SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_PacknHold_Inquiry                                 */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#250453 - Pallet QC (Non TM)                                  */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2012-06-26 1.0  James    Created                                          */
/* 2013-01-18 1.1  James    Add extra msg (james01)                          */
/* 2016-09-30 1.2  Ung      Performance tuning                               */
/* 2018-11-12 1.3  TungGH   Performance                                      */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_PacknHold_Inquiry](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON			-- SQL 2005 Standard
SET QUOTED_IDENTIFIER OFF	
SET ANSI_NULLS OFF   
SET CONCAT_NULL_YIELDS_NULL OFF        

-- Misc variable
DECLARE @b_Success      INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cLoadKey            NVARCHAR( 10),
   
   @cMasterPack         NVARCHAR( 1),
   @cLOC                NVARCHAR( 10),
   @cLOC_Facility       NVARCHAR( 5),
   @cLOC_Category       NVARCHAR( 10),
   @cDropLoc            NVARCHAR( 10),
   @cDropID             NVARCHAR( 18), 
   @cDropIDStatus       NVARCHAR( 20),

   @nCountLoadKey       INT, 
   @nCountLoadKey_MC    INT, 
   @nCartonCnt          INT, 
   @nCnt                INT, 
   @nTtlPageCnt         INT, 
   @nCurPageCnt         INT, 

   
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
   @cFieldAttr15 NVARCHAR( 1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

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
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,

   @cLOC             = V_LOC,
   @cLoadKey         = V_LoadKey, 
   
   @cDropID          = V_String1,
   
   @nCurPageCnt      = V_Integer1, 
   @nTtlPageCnt      = V_Integer2, 

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
IF @nFunc = 526
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 526
   IF @nStep = 1 GOTO Step_1   -- Scn = 860 LOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 861 DROPID, STATUS, CARTON CNT
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1715)
********************************************************************************/
Step_0:
BEGIN
   -- insert to Eventlog
   EXEC RDT.rdt_STD_EventLog
     @cActionType   = '1', -- SignIn
     @cUserID       = @cUserName,
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = @cStorerkey,
     @nStep         = @nStep
        
   -- Set the entry point
   SET @nScn  = 860
   SET @nStep = 1

   -- initialise all variable
   SET @cLOC = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 860
   LOC: (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField01

      --Check if it is blank
      IF ISNULL(@cLOC, '') = ''
      BEGIN
         SET @nErrNo = 76801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc neede
         GOTO Step_1_Fail
      END

      SELECT 
         @cLOC_Facility = Facility, 
         @cLOC_Category = LocationCategory 
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 76802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc not exists
         GOTO Step_1_Fail
      END
      
      IF ISNULL(@cLOC_Facility, '') <> @cFacility
      BEGIN
         SET @nErrNo = 76803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_1_Fail
      END

      IF ISNULL(@cLOC_Category, '') <> 'PACK&HOLD'
      BEGIN
         SET @nErrNo = 76804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not P&H loc
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM DropID WITH (NOLOCK) 
                     WHERE Droploc = @cLOC)
      BEGIN
         SET @nErrNo = 76805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not Loc 
         GOTO Step_1_Fail
      END

      SET @cDropID = ''
      SET @cDropIDStatus = ''
      SET @nCnt = 0
         
      SELECT TOP 1 
         @cDropID = DropID, 
         @cDropIDStatus = CASE WHEN [Status] = 0 THEN '0 - Pallet Build' 
                               WHEN [Status] = 1 THEN '1 - Audit Failed' 
                               WHEN [Status] = 2 THEN '2 - Audit Passed' 
                               WHEN [Status] = 3 THEN '3 - Pack&Hold' 
                               WHEN [Status] = 5 THEN '5 - Staged' 
                               WHEN [Status] = 9 THEN '9 - Shipped'  
                          END, 
      @nCnt = COUNT( DISTINCT DropID) 
      FROM dbo.DropID WITH (NOLOCK) 
      WHERE DropLOC = @cLOC
      GROUP BY DropID, [Status] 
      ORDER BY DropID

      SELECT @nCnt = COUNT( DISTINCT DropID) 
      FROM dbo.DropID WITH (NOLOCK) 
      WHERE DropLOC = @cLOC
      
      SET @nTtlPageCnt = @nCnt
      SET @nCurPageCnt = 1 

      SELECT @cMasterPack = SValue  
      FROM dbo.STORERCONFIG WITH (NOLOCK)  
      WHERE Storerkey = @cStorerkey  
         AND Configkey = 'MASTERPACK'  
   
      SELECT @nCartonCnt = COUNT(DISTINCT 
                                 CASE WHEN ISNULL(PD.Refno, '') <> '' AND ISNULL(PD.Refno2, '') <> '' AND @cMasterPack = '1' 
                                      THEN PD.Refno2 
                                      ELSE PD.Labelno END) 
      FROM dbo.DropidDetail DD WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
      WHERE DD.DropID = @cDropID

      SET @cOutField01 = 'PAGE: ' + RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cDropIDStatus
      SET @cOutField04 = CASE WHEN ISNULL(@nCartonCnt, 0) = 0 THEN 'No Pack Detail' ELSE CAST(@nCartonCnt AS NVARCHAR( 5)) END -- (james01)
      
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
      @cActionType   = '9', -- SignOut
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @nStep         = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
      SET @cLOC = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 861
   DROP ID   (Field01, Input)
   STATUS    (Field01, Input)
   CARTON CNT(Field01, Input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) 
                 WHERE DropLOC = @cLOC
                 AND DropID > @cOutField02)
      BEGIN
         SET @cDropID = ''
         SET @cDropIDStatus = ''
         SET @nCnt = 0
         
         SELECT TOP 1 
            @cDropID = DropID, 
            @cDropIDStatus = CASE WHEN [Status] = 0 THEN '0 - Pallet Build' 
                                  WHEN [Status] = 1 THEN '1 - Audit Failed' 
                                  WHEN [Status] = 2 THEN '2 - Audit Passed' 
                                  WHEN [Status] = 3 THEN '3 - Pack&Hold' 
                                  WHEN [Status] = 5 THEN '5 - Staged' 
                                  WHEN [Status] = 9 THEN '9 - Shipped'  
                             END, 
         @nCnt = COUNT( DISTINCT DropID) 
         FROM dbo.DropID WITH (NOLOCK) 
         WHERE DropLOC = @cLOC
            AND DropID > @cOutField02
         GROUP BY DropID, [Status] 
         ORDER BY DropID

--         SELECT @nCnt = COUNT( DISTINCT DropID) 
--         FROM dbo.DropID WITH (NOLOCK) 
--         WHERE DropLOC = @cLOC
--            AND DropID > @cOutField02
--         
--         SET @nTtlPageCnt = @nCnt
         SET @nCurPageCnt = @nCurPageCnt + 1 

         SELECT @cMasterPack = SValue  
         FROM dbo.STORERCONFIG WITH (NOLOCK)  
         WHERE Storerkey = @cStorerkey  
            AND Configkey = 'MASTERPACK'  
      
         SELECT @nCartonCnt = COUNT(DISTINCT 
                                    CASE WHEN ISNULL(PD.Refno, '') <> '' AND ISNULL(PD.Refno2, '') <> '' AND @cMasterPack = '1' 
                                         THEN PD.Refno2 
                                         ELSE PD.Labelno END) 
         FROM dbo.DropidDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         WHERE DD.DropID = @cDropID

         SET @cOutField01 = 'PAGE: ' + RTRIM(CAST(@nCurPageCnt AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nTtlPageCnt AS NVARCHAR(2)))
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cDropIDStatus
         SET @cOutField04 = CASE WHEN ISNULL(@nCartonCnt, 0) = 0 THEN 'No Pack Detail' ELSE CAST(@nCartonCnt AS NVARCHAR( 5)) END -- (james01)
      END
      ELSE
      BEGIN
         SET @nErrNo = 76806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not more rec
         GOTO Step_2_Fail
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_2_Fail:
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
       Printer_Paper = @cPrinter_Paper,
       -- UserName      = @cUserName,

       V_LOC         = @cLOC,
       V_LoadKey     = @cLoadKey, 
   
       V_String1     = @cDropID,
       
       V_Integer1    = @nCurPageCnt, 
       V_Integer2    = @nTtlPageCnt, 
       
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
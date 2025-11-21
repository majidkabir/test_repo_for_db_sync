SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Stage_Pallet_Inquiry                              */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Allow user to scan any carton label on a pallet                  */
/*          and provide the pallet information. (SOS#200190)                 */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-01-05 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */   
/* 2018-11-14 1.2  TungGH   Performance                                      */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Stage_Pallet_Inquiry](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @bSuccess           INT
        
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

   @cDropID             NVARCHAR(20),
   @cLabelNo            NVARCHAR(20),                
   @cOption             NVARCHAR(1), 
   @cDropIDType         NVARCHAR(10), 
   @nLabelCnt           INT, 
   @nRowCount           INT, 
   @nCNT                INT, 
   @nPageCnt            INT, 
   @nRowRef             INT, 
   @nCurPage            INT, 
   @nTTL_CNT            INT, 
   @dPickUp             DATETIME, 
   @cLOC                NVARCHAR(10), 
   @cDoor               NVARCHAR(30), 
   @cUser               NVARCHAR(18), 
   @dDate               DATETIME, 
   @cEventType          NVARCHAR(2), 
   @cToLocation         NVARCHAR(10), 
   @cUserID             NVARCHAR(18), 
   @cLOCHistory01       NVARCHAR(20), 
   @cLOCHistory02       NVARCHAR(20), 
   @cLOCHistory03       NVARCHAR(20), 
   @cLOCHistory04       NVARCHAR(20), 
   @cLOCHistory05       NVARCHAR(20), 
   @cLOCHistory06       NVARCHAR(20), 
   @cLOCHistory07       NVARCHAR(20), 
   @cLOCHistory08       NVARCHAR(20), 
   @cLOCHistory09       NVARCHAR(20), 
   @cLOCHistory10       NVARCHAR(20), 

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

   @dDate            = V_Lottable04, 
   @dPickUp          = V_Lottable05,
   @cLOC             = V_LOC, 

   @cDropID          = V_String1,
   @cLabelNo         = V_String2,
   @cDropIDType      = V_String3,  
   @cDoor            = V_String5, 
   @cUser            = V_String6, 
   @cLOCHistory01    = V_String7, 
   @cLOCHistory02    = V_String8, 
   @cLOCHistory03    = V_String9, 
   @cLOCHistory04    = V_String10, 
   @cLOCHistory05    = V_String11, 
   @cLOCHistory06    = V_String12, 
   @cLOCHistory07    = V_String13, 
   @cLOCHistory08    = V_String14, 
   @cLOCHistory09    = V_String15, 
   @cLOCHistory10    = V_String16, 
   
   @nLabelCnt        = V_Integer1,
   @nRowRef          = V_Integer2, 
   @nCurPage         = V_Integer3, 
   @nPageCnt         = V_Integer4, 

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
IF @nFunc = 1647
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1647
   IF @nStep = 1 GOTO Step_1   -- Scn = 2630  DropID/Label No
   IF @nStep = 2 GOTO Step_2   -- Scn = 2631  Information/Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 2632  Information
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1647)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2630
   SET @nStep = 1

   -- initialise all variable
   SET @cDropID = ''
   SET @cLabelNo = ''

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2630
   DROPID   (Field01, input)
   LABEL NO (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01
      SET @cLabelNo = @cInField02

      IF ISNULL(@cDropID, '') = '' AND ISNULL(@cLabelNo, '') = ''         
      BEGIN                
         SET @nErrNo = 71941                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROPID/LBL req                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END                
                
      IF ISNULL(@cDropID, '') <> '' AND ISNULL(@cLabelNo, '') <> ''                
      BEGIN             
         SET @nErrNo = 71942                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROPID/LBL ONLY                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END                

      -- DropID validation
      IF ISNULL(@cDropID, '') <> '' AND ISNULL(@cLabelNo, '') = ''   
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)            
                        WHERE DropID = @cDropID)            
         BEGIN            
            SET @nErrNo = 71943                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID DROPID                
            EXEC rdt.rdtSetFocusField @nMobile, 1                
            GOTO Step_1_Fail                
         END          

         SELECT 
               @cDropIDType = DropIDType, 
               @cLOC = DropLOC, 
               @cDoor = AdditionalLOC, 
               @cUser = EditWho, 
               @dDate = EditDate 
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID
      END

      -- LabelNo validation
      IF ISNULL(@cDropID, '') = '' AND ISNULL(@cLabelNo, '') <> ''   
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPIDDetail WITH (NOLOCK)            
                        WHERE ChildID = @cLabelNo)            
         BEGIN            
            SET @nErrNo = 71944                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID LABEL                
            EXEC rdt.rdtSetFocusField @nMobile, 1                
            GOTO Step_1_Fail                
         END          

         SELECT @nRowCount = COUNT(DISTINCT DropID) FROM dbo.DROPIDDetail WITH (NOLOCK)
         WHERE ChildID = @cLabelNo 

         IF @nRowCount > 1
         BEGIN
            -- If more than 1 dropid return then always take the DropidType = 'P'
            SELECT TOP 1 
               @cDropID = DropID.DropID, 
               @cDropIDType = DropID.DropIDType, 
               @cLOC = DropID.DropLOC, 
               @cDoor = DropID.AdditionalLOC, 
               @cUser = DropID.EditWho, 
               @dDate = DropID.EditDate 
            FROM dbo.DROPIDDetail DDTL WITH (NOLOCK)
            JOIN dbo.DropID DropID WITH (NOLOCK) ON DDTL.DropID = DropID.DropID
            WHERE DDTL.ChildID = @cLabelNo
            AND DropID.DropIDType = 'P'

            SET @cDropIDType = 'P'
         END
         ELSE
         BEGIN
            SELECT TOP 1 
               @cDropID = DropID.DropID, 
               @cDropIDType = DropID.DropIDType, 
               @cLOC = DropID.DropLOC, 
               @cDoor = DropID.AdditionalLOC, 
               @cUser = DropID.EditWho, 
               @dDate = DropID.EditDate 
            FROM dbo.DROPIDDetail DDTL WITH (NOLOCK)
            JOIN dbo.DropID DropID WITH (NOLOCK) ON DDTL.DropID = DropID.DropID
            WHERE ChildID = @cLabelNo
         END
      END

      SELECT @nLabelCnt = COUNT(DISTINCT ChildID) 
      FROM dbo.DROPIDDetail WITH (NOLOCK)
      WHERE DropID = @cDropID

      IF EXISTS (SELECT MBOL.UserDefine07 
         FROM dbo.MBOL MBOL WITH (NOLOCK)
         JOIN dbo.MBOLDetail MBOLD WITH (NOLOCK) ON MBOL.MBOLKey = MBOLD.MBOLKey
         JOIN dbo.ORDERS O WITH (NOLOCK) ON MBOLD.OrderKey = O.OrderKey
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
         JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON PH.PickslipNo = PD.PickslipNo
         JOIN dbo.DROPIDDetail DROPIDD WITH (NOLOCK) ON PD.LabelNo = DROPIDD.ChildID
         WHERE DROPIDD.DropID = @cDropID
         GROUP BY MBOL.UserDefine07
         HAVING COUNT(DISTINCT MBOL.UserDefine07) > 1)
      BEGIN
         SET @dPickUp = NULL
      END
      ELSE
      BEGIN
         SELECT TOP 1 @dPickUp = MBOL.UserDefine07 
         FROM dbo.MBOL MBOL WITH (NOLOCK)
         JOIN dbo.MBOLDetail MBOLD WITH (NOLOCK) ON MBOL.MBOLKey = MBOLD.MBOLKey
         JOIN dbo.ORDERS O WITH (NOLOCK) ON MBOLD.OrderKey = O.OrderKey
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
         JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON PH.PickslipNo = PD.PickslipNo
         JOIN dbo.DROPIDDetail DROPIDD WITH (NOLOCK) ON PD.LabelNo = DROPIDD.ChildID
         WHERE DROPIDD.DropID = @cDropID
      END

      -- Prev next screen
      SET @cOutField01 = ISNULL(RTRIM(@cDropID), '') + ' - ' + ISNULL(RTRIM(@cDropIDType), '')
      SET @cOutField02 = @nLabelCnt
      SET @cOutField03 = CASE 
                         WHEN ISNULL(@dPickUp, 0) = 0 THEN 'MULTI' 
                         ELSE rdt.rdtFormatDate(@dPickUp) + ' ' + CONVERT(CHAR(8),@dPickUp,108) 
                         END
      SET @cOutField04 = @cLOC 
      SET @cOutField05 = @cDoor 
      SET @cOutField06 = @cUser 
      SET @cOutField07 = rdt.rdtFormatDate(@dDate) + ' ' + CONVERT(CHAR(8),@dDate,108)
      SET @cOutField08 = '' 

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
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 2631
   INFORMATION    (field01)
   OPTION         (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cOption = @cInField08

      IF ISNULL(RTRIM(@cOption), '') <> ''
      BEGIN
         IF @cOption NOT IN ('1', '2')
         BEGIN
            SET @nErrNo = 71945
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Opt
            GOTO Step_2_Fail  
         END

         IF @cOption = '1'
         BEGIN
            IF EXISTS (SELECT 1
               FROM dbo.V_DropID_EventLog WITH (NOLOCK) 
               WHERE DropID = @cDropID)
            BEGIN
               SET @cLOCHistory01 = ''
               SET @cLOCHistory02 = ''
               SET @cLOCHistory03 = ''
               SET @cLOCHistory04 = ''
               SET @cLOCHistory05 = ''
               SET @cLOCHistory06 = ''
               SET @cLOCHistory07 = ''
               SET @cLOCHistory08 = ''
               SET @cLOCHistory09 = ''
               SET @cLOCHistory10 = ''
               SET @nCNT = 1

               -- Declare temp table to store data 
               IF OBJECT_ID('tempdb..#DropID_EventLog') IS NOT NULL   
               Drop TABLE #DropID_EventLog

               CREATE TABLE #DropID_EventLog  (   
               RowRef        BIGINT IDENTITY(1,1)  Primary Key, 
               EventType     NVARCHAR(20),              
               DropID        NVARCHAR(18),         
               ToLocation    NVARCHAR(10),               
               UserID        NVARCHAR(18))              

               INSERT INTO #DropID_EventLog
               SELECT CASE EventType 
                      WHEN 'Picking' THEN 'PK'
                      WHEN 'Move' THEN 'MV' 
                      ELSE ''
                      END AS EventType,
                      DropId, 
                      ToLocation, 
                      UserID 
               FROM dbo.V_DropID_EventLog WITH (NOLOCK) 
               WHERE DropID = @cDropID
               GROUP BY DropId , DropLoc , EventType , Location, ToLocation, UserID 

               SELECT @nTTL_CNT = COUNT(1) FROM #DropID_EventLog

               DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT RowRef, EventType, ToLocation, UserID 
               FROM #DropID_EventLog  
               ORDER BY RowRef

               OPEN CUR_LOOP
               FETCH NEXT FROM CUR_LOOP INTO @nRowRef, @cEventType, @cToLocation, @cUserID 
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @nCNT = 1
                     SET @cLOCHistory01 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 2
                     SET @cLOCHistory02 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 3
                     SET @cLOCHistory03 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 4
                     SET @cLOCHistory04 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 5
                     SET @cLOCHistory05 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 6
                     SET @cLOCHistory06 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 7
                     SET @cLOCHistory07 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 8
                     SET @cLOCHistory08 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 9
                     SET @cLOCHistory09 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
                  IF @nCNT = 10
                     SET @cLOCHistory10 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')

                  SET @nCNT = @nCNT + 1
                  IF @nCNT > 10
                     BREAK

                  FETCH NEXT FROM CUR_LOOP INTO @nRowRef, @cEventType, @cToLocation, @cUserID
               END
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP

               SET @nPageCnt = (@nTTL_CNT/10) + 1
               SET @nCurPage = 1
            END
         END

         SET @cOutField01 = RTRIM(CAST(@nCurPage AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nPageCnt AS NVARCHAR(2)))
         SET @cOutField02 = ISNULL(RTRIM(@cDropID), '') + '-' + ISNULL(RTRIM(@cDropIDType), '')
         SET @cOutField03 = @cLOCHistory01
         SET @cOutField04 = @cLOCHistory02
         SET @cOutField05 = @cLOCHistory03
         SET @cOutField06 = @cLOCHistory04
         SET @cOutField07 = @cLOCHistory05
         SET @cOutField08 = @cLOCHistory06
         SET @cOutField09 = @cLOCHistory07
         SET @cOutField10 = @cLOCHistory08
         SET @cOutField11 = @cLOCHistory09
         SET @cOutField12 = @cLOCHistory10

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         IF OBJECT_ID('tempdb..#DropID_EventLog') IS NOT NULL   
         Drop TABLE #DropID_EventLog
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cDropID = ''
      SET @cLabelNo = '' 
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END  
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField08 = ''
   END
   GOTO Quit
   
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2632
   INFORMATION (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      IF @nCurPage < @nPageCnt
      BEGIN
         SET @cLOCHistory01 = ''
         SET @cLOCHistory02 = ''
         SET @cLOCHistory03 = ''
         SET @cLOCHistory04 = ''
         SET @cLOCHistory05 = ''
         SET @cLOCHistory06 = ''
         SET @cLOCHistory07 = ''
         SET @cLOCHistory08 = ''
         SET @cLOCHistory09 = ''
         SET @cLOCHistory10 = ''
         SET @nCNT = 1

         -- Declare temp table to store data 
         IF OBJECT_ID('tempdb..#DropID_EventLog1') IS NOT NULL   
         Drop TABLE #DropID_EventLog1
      
         CREATE TABLE #DropID_EventLog1  (   
         RowRef        BIGINT IDENTITY(1,1)  Primary Key, 
         EventType     NVARCHAR(20),              
         DropID        NVARCHAR(18),         
         ToLocation    NVARCHAR(10),               
         UserID        NVARCHAR(18))              

         INSERT INTO #DropID_EventLog1
         SELECT CASE EventType 
                WHEN 'Picking' THEN 'PK'
                WHEN 'Move' THEN 'MV' 
                ELSE ''
                END AS EventType,
                DropId, 
                ToLocation, 
                UserID 
         FROM dbo.V_DropID_EventLog WITH (NOLOCK) 
         WHERE DropID = @cDropID
         GROUP BY DropId , DropLoc , EventType , Location, ToLocation, UserID 

         SELECT @nTTL_CNT = COUNT(1) FROM #DropID_EventLog1

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT RowRef, EventType, ToLocation, UserID 
         FROM #DropID_EventLog1  
         WHERE RowRef > @nRowRef
         ORDER BY RowRef

         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @nRowRef, @cEventType, @cToLocation, @cUserID 
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @nCNT = 1
               SET @cLOCHistory01 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 2
               SET @cLOCHistory02 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 3
               SET @cLOCHistory03 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 4
               SET @cLOCHistory04 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 5
               SET @cLOCHistory05 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 6
               SET @cLOCHistory06 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 7
               SET @cLOCHistory07 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 8
               SET @cLOCHistory08 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 9
               SET @cLOCHistory09 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')
            IF @nCNT = 10
               SET @cLOCHistory10 = ISNULL(RTRIM(@cEventType), '') + '-' + ISNULL(RTRIM(@cToLocation), '') + '/' + ISNULL(RTRIM(@cUserID), '')

            SET @nCNT = @nCNT + 1
            IF @nCNT > 10
               BREAK

            FETCH NEXT FROM CUR_LOOP INTO @nRowRef, @cEventType, @cToLocation, @cUserID
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         SET @nPageCnt = (@nTTL_CNT/10) + 1
         SET @nCurPage = @nCurPage + 1
      END
      SET @cErrMsg = 'NO MORE RECORDS'

      SET @cOutField01 = RTRIM(CAST(@nCurPage AS NVARCHAR(2))) + '/' + LTRIM(CAST(@nPageCnt AS NVARCHAR(2)))
      SET @cOutField02 = ISNULL(RTRIM(@cDropID), '') + '-' + ISNULL(RTRIM(@cDropIDType), '')
      SET @cOutField03 = @cLOCHistory01
      SET @cOutField04 = @cLOCHistory02
      SET @cOutField05 = @cLOCHistory03
      SET @cOutField06 = @cLOCHistory04
      SET @cOutField07 = @cLOCHistory05
      SET @cOutField08 = @cLOCHistory06
      SET @cOutField09 = @cLOCHistory07
      SET @cOutField10 = @cLOCHistory08
      SET @cOutField11 = @cLOCHistory09
      SET @cOutField12 = @cLOCHistory10

      SET @nScn = @nScn 
      SET @nStep = @nStep 

      IF OBJECT_ID('tempdb..#DropID_EventLog1') IS NOT NULL   
      Drop TABLE #DropID_EventLog1
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
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 
   END
   GOTO Quit
END
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

      V_Lottable04  = @dDate,
      V_Lottable05  = @dPickUp,
      V_LOC         = @cLOC, 

      V_String1     = @cDropID,
      V_String2     = @cLabelNo,
      V_String3     = @cDropIDType,
      V_String5     = @cDoor, 
      V_String6     = @cUser, 
      V_String7     = @cLOCHistory01, 
      V_String8     = @cLOCHistory02, 
      V_String9     = @cLOCHistory03, 
      V_String10    = @cLOCHistory04, 
      V_String11    = @cLOCHistory05, 
      V_String12    = @cLOCHistory06, 
      V_String13    = @cLOCHistory07, 
      V_String14    = @cLOCHistory08, 
      V_String15    = @cLOCHistory09, 
      V_String16    = @cLOCHistory10, 
      
      V_Integer1    = @nLabelCnt,
      V_Integer2    = @nRowRef, 
      V_Integer3    = @nCurPage, 
      V_Integer4    = @nPageCnt, 

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
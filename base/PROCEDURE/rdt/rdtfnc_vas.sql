SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_VAS                                          */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author     Purposes                                */  
/* 2009-06-10   1.0  Vicky      Created                                 */  
/* 2016-09-30   1.1  Ung        Performance tuning                      */  
/* 2018-11-21   1.2  Gan        Performance tuning                      */
/************************************************************************/  
CREATE  PROC [RDT].[rdtfnc_VAS] (  
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
  
   @cOrderRef           NVARCHAR( 30),   
   @cUserID             NVARCHAR( 18),   
   @cSKU                NVARCHAR( 20),  
   @cQTY                NVARCHAR(  5),  
   @cOption             NVARCHAR(  1),  
   @cOrdLineNo          NVARCHAR(  5),  
   @cType               NVARCHAR( 10),  
  
   @cErrMsg1            NVARCHAR(20),  
   @cErrMsg2            NVARCHAR(20),  
   @cErrMsg3            NVARCHAR(20),  
   @cErrMsg4            NVARCHAR(20),  
        
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
   @nStep_1          INT,  @nScn_1          INT,    
   @nStep_2          INT,  @nScn_2          INT  
  
SELECT  
   @nStep_1          = 1  
  
  
SELECT @nScn_1  =  CASE WHEN @nFunc = 703 THEN 730  
                        WHEN @nFunc = 704 THEN 731  
                        WHEN @nFunc = 705 THEN 732  
                        WHEN @nFunc = 706 THEN 733  
                        WHEN @nFunc = 707 THEN 734  
                   ELSE '' END  
                            
  
  
-- IF @nFunc = 703  
-- BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 703  
   IF @nStep = 1  GOTO Step_1           -- Scn = 730  
--END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 703  
********************************************************************************/  
Step_Start:  
BEGIN  
   
   -- Prepare label screen var  
   SET @cOutField01 = ''  
   SET @cOutField02 = ''  
   SET @cOutField03 = ''  
   SET @cOutField04 = '1'  
  
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
  
   SET @cQTY = '0'  
  
   -- Go to screen  
   SET @nScn = @nScn_1  
   SET @nStep = @nStep_1  
   GOTO Quit  
  
   Step_Start_Fail:  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- LOC  
   END  
END  
GOTO Quit  
  
  
  
/***********************************************************************************  
Scn = 704. Ticketing screen  
   ORDER #       (field01)  
   SKU           (field02)  
   QTY           (field03)  
   OPTION        (field04)  
***********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
     -- Screen mapping  
     SET @cOrderRef = @cInField01 -- OrderRef  
     SET @cSKU      = @cInField02 -- SKU  
     SET @cQTY      = @cInField03 -- QTY  
     SET @cOption   = @cInField04 -- Option  
  
     IF ISNULL(RTRIM(@cOrderRef), '') = ''  
     BEGIN  
         SET @nErrNo = 50034  
         SET @cErrMsg = rdt.rdtgetmessage( 50034, @cLangCode, 'DSP') -- Order# Req  
  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = @cQTY  
         SET @cOutField04 = '1'  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderRef  
         GOTO Step_1_Fail  
     END  
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.ORDERS WITH (NOLOCK)   
--                    WHERE Orderkey = @cOrderRef  
--                    AND   Storerkey = @cStorerkey)  
--     BEGIN  
--         SET @nErrNo = 50035  
--         SET @cErrMsg = rdt.rdtgetmessage( 50035, @cLangCode, 'DSP') -- Invalid Order#  
--  
--         SET @cOutField01 = ''  
--         SET @cOutField02 = @cSKU  
--         SET @cOutField03 = @cQTY  
--         SET @cOutField04 = '1'  
--         EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderRef  
--         GOTO Step_1_Fail  
--     END   
  
     IF ISNULL(RTRIM(@cSKU), '') = ''  
     BEGIN  
         SET @nErrNo = 50036  
         SET @cErrMsg = rdt.rdtgetmessage( 50036, @cLangCode, 'DSP') -- SKU Req  
  
         SET @cOutField01 = @cOrderRef  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cQTY  
         SET @cOutField04 = '1'  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU  
         GOTO Step_1_Fail  
     END  
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.SKU WITH (NOLOCK)   
--                    WHERE SKU = @cSKU and Storerkey = @cStorerkey)  
--     BEGIN  
--         SET @nErrNo = 50037  
--         SET @cErrMsg = rdt.rdtgetmessage( 50037, @cLangCode, 'DSP') -- Invalid SKU  
--  
--         SET @cOutField01 = @cOrderRef  
--         SET @cOutField02 = ''  
--         SET @cOutField03 = @cQTY  
--         SET @cOutField04 = '1'  
--         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU  
--         GOTO Step_1_Fail  
--     END   
  
--     IF NOT EXISTS (SELECT 1 FROM DBO.ORDERDETAIL WITH (NOLOCK)   
--                    WHERE Orderkey = @cOrderRef AND SKU = @cSKU AND Storerkey = @cStorerkey)  
--     BEGIN  
--         SET @nErrNo = 50038  
--         SET @cErrMsg = rdt.rdtgetmessage( 50038, @cLangCode, 'DSP') -- SKU not in ORD  
--  
--         SET @cOutField01 = @cOrderRef  
--         SET @cOutField02 = ''  
--         SET @cOutField03 = @cQTY  
--         SET @cOutField04 = '1'  
--         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU  
--         GOTO Step_1_Fail  
--     END   
  
--     SELECT @cOrdLineNo = OrderLineNumber  
--     FROM DBO.ORDERDETAIL WITH (NOLOCK)   
--     WHERE Orderkey = @cOrderRef   
--     AND   SKU = @cSKU   
--     AND Storerkey = @cStorerkey  
--  
--     IF ISNULL(RTRIM(@cQTY), '') = ''  
--     BEGIN    
--         SET @nErrNo = 50039  
--         SET @cErrMsg = rdt.rdtgetmessage( 50039, @cLangCode, 'DSP') -- QTY Req  
--  
--         SET @cOutField01 = @cOrderRef  
--         SET @cOutField02 = @cSKU  
--         SET @cOutField03 = ''  
--         SET @cOutField04 = '1'  
--         EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY  
--         GOTO Step_1_Fail  
--      END    
    
     IF rdt.rdtIsValidQty(@cQTY, 1) = 0     
     BEGIN    
         SET @nErrNo = 50040  
         SET @cErrMsg = rdt.rdtgetmessage( 50040, @cLangCode, 'DSP') -- Invalid QTY  
  
         SET @cOutField01 = @cOrderRef  
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = ''  
         SET @cOutField04 = '1'  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- QTY  
         GOTO Step_1_Fail  
     END     
  
  
     IF @cOption <> '1' AND @cOption <> '2'  
     BEGIN  
         SET @nErrNo = 50041  
         SET @cErrMsg = rdt.rdtgetmessage( 50041, @cLangCode, 'DSP') -- Invalid Option  
  
         SET @cOutField01 = @cOrderRef  
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = @cQTY  
         SET @cOutField04 = '1'  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Option  
         GOTO Step_1_Fail  
     END  
  
     SELECT @cType = CASE WHEN @nFunc = 703 THEN 'TKT'  
                          WHEN @nFunc = 704 THEN 'NDC'  
                          WHEN @nFunc = 705 THEN 'CTN'  
                          WHEN @nFunc = 706 THEN 'BUN'  
                          WHEN @nFunc = 707 THEN 'PCK'  
                          ELSE '' END  
  
     IF @cOption = '1'  
     BEGIN  
       IF NOT EXISTS (SELECT 1 FROM RDT.rdtVASLog WITH (NOLOCK)  
                      WHERE Ref1 = @cOrderRef   
        AND   Ref2 = @cOrdLineNo  
                      AND   Ref3 = @cSKU  
                      AND   Type = @cType  
                      AND   QTY = @cQTY  
                      AND   Facility = @cFacility  
                      AND   UserName = @cUserName  
                      AND   Status IN ( '0', '9') )  
       BEGIN  
          -- Insert rdtVASLog  
          INSERT INTO RDT.rdtVASLog (Type, UserName, Facility, Ref1, Ref2, Ref3, QTY, EndDate)  
          VALUES (@cType, @cUserName, @cFacility, @cOrderRef, @cOrdLineNo, @cSKU, CAST(@cQTY AS INT), '')  
  
          SET @cErrMsg = 'Start Job'  
       END  
       ELSE IF EXISTS (SELECT 1 FROM RDT.rdtVASLog WITH (NOLOCK)  
                       WHERE Ref1 = @cOrderRef   
                       AND   Ref2 = @cOrdLineNo  
                       AND   Ref3 = @cSKU  
                       AND   Type = @cType  
                       AND   QTY = @cQTY  
                       AND   Facility = @cFacility  
                       AND   UserName = @cUserName  
                       AND   Status = '0')  
       BEGIN  
            SET @nErrNo = 50042  
            SET @cErrMsg = rdt.rdtgetmessage( 50042, @cLangCode, 'DSP') -- Job Started/Exist  
     
            SET @cOutField01 = @cOrderRef  
            SET @cOutField02 = @cSKU  
            SET @cOutField03 = @cQTY  
            SET @cOutField04 = '1'  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Option  
            GOTO Step_1_Fail  
       END  
       ELSE IF EXISTS (SELECT 1 FROM RDT.rdtVASLog WITH (NOLOCK)  
                       WHERE Ref1 = @cOrderRef   
                       AND   Ref2 = @cOrdLineNo  
                       AND   Ref3 = @cSKU  
                       AND   Type = @cType  
                       AND   QTY = @cQTY  
                       AND   Facility = @cFacility  
                       AND   UserName = @cUserName  
                       AND   Status = '9')  
       BEGIN  
            SET @nErrNo = 50043  
            SET @cErrMsg = rdt.rdtgetmessage( 50043, @cLangCode, 'DSP') -- Job Closed  
     
            SET @cOutField01 = @cOrderRef  
            SET @cOutField02 = @cSKU  
            SET @cOutField03 = @cQTY  
            SET @cOutField04 = '1'  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Option  
            GOTO Step_1_Fail  
       END  
     END  
     ELSE IF @cOption = '2'  
     BEGIN  
       -- Check Record exists in rdtVASLog  
       IF NOT EXISTS (SELECT 1 FROM RDT.rdtVASLog WITH (NOLOCK)  
                      WHERE Ref1 = @cOrderRef   
                      AND   Ref2 = @cOrdLineNo  
                      AND   Ref3 = @cSKU  
                      AND   Type = @cType  
                      AND   QTY = @cQTY  
                      AND   Facility = @cFacility  
                      AND   UserName = @cUserName  
                      AND   Status = '0')  
       BEGIN  
            SET @nErrNo = 50044  
            SET @cErrMsg = rdt.rdtgetmessage( 50044, @cLangCode, 'DSP') -- Job Not Started  
     
            SET @cOutField01 = @cOrderRef  
            SET @cOutField02 = @cSKU  
            SET @cOutField03 = @cQTY  
            SET @cOutField04 = '1'  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Option  
            GOTO Step_1_Fail  
       END  
       ELSE  
       BEGIN  
          UPDATE RDT.rdtVASLog WITH (ROWLOCK)  
            SET STATUS = '9',  
                EndDate = GETDATE()  
          WHERE UserName = @cUserName  
          AND   Ref1 = @cOrderRef  
          AND   Ref2 = @cOrdLineNo  
          AND   Ref3 = @cSKU  
          AND   Type = @cType  
          AND   Facility = @cFacility  
          AND   Status = '0'  
  
          SET @cErrMsg = 'End Job'  
       END  
     END  
  
     -- Reset  
     SET @cOutField01 = ''  
     SET @cOutField02 = ''  
     SET @cOutField03 = ''  
     SET @cOutField04 = '1'  
  
     SET @cOrderRef = ''  
     SET @cSKU = ''  
     SET @cQTY = ''  
     SET @cOption = ''  
  
     EXEC rdt.rdtSetFocusField @nMobile, 1 -- OrderRef  
  
   -- Stay in same screen  
   SET @nScn = @nScn  
   SET @nStep = @nStep  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
  
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
      -- UserName       = @cUserName,  
        
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
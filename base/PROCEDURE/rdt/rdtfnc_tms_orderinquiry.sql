SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/   
/* Copyright: LF                                                              */   
/* Purpose: IDSCN                                                             */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2016-04-29 1.0  ChewKP     SOS#356239 Created                              */
/* 2018-11-15 1.1  TungGH     Performance                                     */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TMS_OrderInquiry] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE   
   @nCount      INT,  
   @nRowCount   INT  
  
-- RDT.RDTMobRec variable  
DECLARE   
   @nFunc      INT,  
   @nScn       INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @nInputKey  INT,  
   @nMenu      INT,  
  
   @cStorerKey NVARCHAR( 15),  
   @cFacility  NVARCHAR( 5),   
   @cPrinter   NVARCHAR( 20),   
   @cUserName  NVARCHAR( 18),  
     
   @nError        INT,  
   @b_success     INT,  
   @n_err         INT,       
   @c_errmsg      NVARCHAR( 250),   
   @cPUOM         NVARCHAR( 10),      
   @bSuccess      INT,  
  
   @cCarrierCode  NVARCHAR(10),
   @nCartonCount  INT, 
   @nOrderCount   INT,
   @nPageCount    INT,
   @cLastOrderNo  NVARCHAR(10), 
   @cOrderNo      NVARCHAR(10),
   @nTotalCartonCount   INT,

        
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
     
-- Load RDT.RDTMobRec  
SELECT   
   @nFunc      = Func,  
   @nScn       = Scn,  
   @nStep      = Step,  
   @nInputKey  = InputKey,  
   @nMenu      = Menu,  
   @cLangCode  = Lang_code,  
  
   @cStorerKey = StorerKey,  
   @cFacility  = Facility,  
   @cPrinter   = Printer,   
   @cUserName  = UserName,  
     
  
   @cPUOM       = V_UOM,  
   
   --@cOrderKey   = V_OrderKey,  -
   @cCarrierCode = V_String1,  
   @cLastOrderNo = V_String4, 
   
   @nOrderCount  = V_Integer1,
   @nCartonCount = V_Integer2,
   @nPageCount   = V_Integer3,
     
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
Declare @n_debug INT  
  
SET @n_debug = 0  
  
  
  
IF @nFunc = 1186  -- Order Inquiry 
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- TMS Order Inquiry 
   IF @nStep = 1 GOTO Step_1   -- Scn = 4630. Carrier Code
   IF @nStep = 2 GOTO Step_2   -- Scn = 4631. OrderNo, Option
   
  
END  
  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. func = 1186. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Get prefer UOM  
   SET @cPUOM = ''  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
   -- Initiate var  
 -- EventLog - Sign In Function  
   EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep 
       
     
   -- Init screen  
   SET @cOutField01 = ''   
   SET @cOutField04 = ''   
   SET @cOutField05 = ''   
   SET @cOutField06 = ''   
   SET @cOutField07 = ''   
   SET @cOutField08 = ''   
   SET @cOutField09 = ''   
   SET @cOutField10 = ''   
   
   SET @nOrderCount = 0 
   SET @nCartonCount = 0
   SET @cLastOrderNo = ''
   
   -- Set the entry point  
   SET @nScn = 4630  
   SET @nStep = 1  
   
   EXEC rdt.rdtSetFocusField @nMobile, 1  
   
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 4630.   
   Carrier Code (Input , Field01)  
 
     
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      SET @cCarrierCode = ISNULL(RTRIM(@cInField01),'')  
           
      
      IF @cCarrierCode <> '' 
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                         WHERE DropLoc = @cCarrierCode
                         AND AddWho = @cUserName
                         AND DATEADD(dd, DATEDIFF(dd, 0, AddDate), 0) = DATEADD(dd, DATEDIFF(dd, 0, GetDate()), 0)  ) 
         BEGIN
            SET @nErrNo = 100001  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RecNotFound  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_1_Fail  
         END
      END



      SELECT @nOrderCount = Count(Distinct TrackingNo) 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE DropLoc = CASE WHEN @cCarrierCode = '' THEN DropLoc ELSE @cCarrierCode END
      AND AddWho = @cUserName
      AND DATEADD(dd, DATEDIFF(dd, 0, AddDate), 0) = DATEADD(dd, DATEDIFF(dd, 0, GetDate()), 0)
      
      SELECT @nCartonCount = Count(Distinct CaseID) 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE DropLoc = CASE WHEN @cCarrierCode = '' THEN DropLoc ELSE @cCarrierCode END
      AND AddWho = @cUserName
      AND DATEADD(dd, DATEDIFF(dd, 0, AddDate), 0) = DATEADD(dd, DATEDIFF(dd, 0, GetDate()), 0)
      
      
      SET @nPageCount = 1 
      SET @cOutField11 = @nPageCount 
      SET @cOutField12 = CEILING(CAST ( (@nOrderCount / 7.1) AS FLOAT ) )
      
      
      SET @cOutField01 = @cCarrierCode 
      SET @cOutField02 = @nOrderCount 
      SET @cOutField03 = @nCartonCount 
      
      SET @nCount = 1 
      
      DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      
      SELECT TrackingNo
           , Count(CaseID) 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE DropLoc = CASE WHEN @cCarrierCode = '' THEN DropLoc ELSE @cCarrierCode END
      AND AddWho = @cUserName
      AND DATEADD(dd, DATEDIFF(dd, 0, AddDate), 0) = DATEADD(dd, DATEDIFF(dd, 0, GetDate()), 0)
      Group By TrackingNo 
      ORDER BY TrackingNo
      
      OPEN C_TOTE_DETAIL  
      FETCH NEXT FROM C_TOTE_DETAIL INTO  @cOrderNo , @nTotalCartonCount  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         
         IF @nCount > 8 
         BEGIN 
            SET @cLastOrderNo = @cOrderNo 
            BREAK
         END
         
         IF @nCount = 1  
            SET @cOutField04 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 2  
            SET @cOutField05 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 3  
            SET @cOutField06 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 4  
            SET @cOutField07 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 5  
            SET @cOutField08 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 6  
            SET @cOutField09 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 7  
            SET @cOutField10 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 

         
         SET @nCount = @nCount + 1 

         FETCH NEXT FROM C_TOTE_DETAIL INTO  @cOrderNo , @nTotalCartonCount  
      END
      CLOSE C_TOTE_DETAIL          
      DEALLOCATE C_TOTE_DETAIL 
      
      IF @nCount > 1 
      BEGIN
         -- GOTO Next Screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
       
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
      ELSE
      BEGIN
         SET @nErrNo = 100002 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RecNotFound  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END
   END  -- Inputkey = 1  
  
  
   IF @nInputKey = 0   
   BEGIN  
      -- EventLog - Sign In Function  
       EXEC RDT.rdt_STD_EventLog  
        @cActionType = '9', -- Sign in function  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep  
          
      --go to main menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
        
        
        
   END  
   GOTO Quit  
  
   STEP_1_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
          
      EXEC rdt.rdtSetFocusField @nMobile, 1  
   END  
     
  
END   
GOTO QUIT  
  
  
/********************************************************************************  
Step 2. Scn = 4570.   
   OrderNo (Input, Field01)
   OrderCount (Field02) 
   Option (Input, Field02)
     
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      
      SET @nCount = 1 

      DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      
      SELECT TrackingNo
           , Count(CaseID) 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE DropLoc = CASE WHEN @cCarrierCode = '' THEN DropLoc ELSE @cCarrierCode END
      AND AddWho = @cUserName
      AND TrackingNo >= @cLastOrderNo 
      AND DATEADD(dd, DATEDIFF(dd, 0, AddDate), 0) = DATEADD(dd, DATEDIFF(dd, 0, GetDate()), 0)
      Group By TrackingNo 
      ORDER BY TrackingNo
      
      OPEN C_TOTE_DETAIL  
      FETCH NEXT FROM C_TOTE_DETAIL INTO  @cOrderNo , @nTotalCartonCount  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
                 
      
         IF @nCount > 8 
         BEGIN 
            SET @cLastOrderNo = @cOrderNo 
            BREAK
         END
         ELSE 
         BEGIN
            SET @cLastOrderNo = ''
         END
         
         IF @nCount = 1  
            SET @cOutField04 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 2  
            SET @cOutField05 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 3  
            SET @cOutField06 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 4  
            SET @cOutField07 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 5  
            SET @cOutField08 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 6  
            SET @cOutField09 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 
         ELSE IF @nCount = 7  
            SET @cOutField10 = @cOrderNo + ' ' + CAST(@nTotalCartonCount AS NVARCHAR(3)) 

         
         SET @nCount = @nCount + 1 
         
         FETCH NEXT FROM C_TOTE_DETAIL INTO  @cOrderNo , @nTotalCartonCount  
         
      END
      CLOSE C_TOTE_DETAIL          
      DEALLOCATE C_TOTE_DETAIL 
      
      IF @@CURSOR_ROWS = 0 
      BEGIN
         SET @nScn = @nScn - 1   
         SET @nStep = @nStep - 1  
         
      END   
      
      SET @nPageCount = @nPageCount + 1 
      SET @cOutField11 = @nPageCount 
      SET @cOutField12 = CEILING(CAST ( (@nOrderCount / 7.1) AS FLOAT ) )
      
      
      SET @cOutField01 = @cCarrierCode 
      SET @cOutField02 = @nOrderCount 
      SET @cOutField03 = @nCartonCount 
      
       
    
   END  -- Inputkey = 1  
  
  
   IF @nInputKey = 0   
   BEGIN  
        
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
        
      SET @nScn = @nScn - 1   
      SET @nStep = @nStep - 1   
        
        
   END  
   GOTO Quit  
  
--   STEP_2_FAIL:  
--   BEGIN  
--      SET @cOutField01 = ''
--      SET @cOutField02 = @nOrderCount 
--      SET @cOutField03 = ''  
--      
--  
--      EXEC rdt.rdtSetFocusField @nMobile, 1  
--   END  
     
  
END   
GOTO QUIT  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
  
BEGIN  
 UPDATE RDTMOBREC WITH (ROWLOCK) SET   
      ErrMsg = @cErrMsg,   
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,   
      Printer   = @cPrinter,   
      UserName  = @cUserName,  
      InputKey  = @nInputKey,  
      
  
      V_UOM      = @cPUOM,  
      --V_OrderKey = @cOrderKey,  
    
      V_String1  = @cCarrierCode,
      V_String4  = @cLastOrderNo,
      
      V_Integer1 = @nOrderCount, 
      V_Integer2 = @nCartonCount,
      V_Integer3 = @nPageCount,
        
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
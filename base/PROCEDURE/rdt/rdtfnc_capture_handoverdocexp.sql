SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Capture_HandOverDocExp                             */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Handle Exceptional Handover Document                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2021-05-17   1.0  Chermaine   WMS-16968. Created                           */
/* 2021-09-10   1.1  Chermaine   WMS-17807 Add codelkup for screen Name       */
/*                               Add SKU screen (cc01)                        */
/* 2022-11-09   1.2  Ung         Performance tuning for D11                   */
/******************************************************************************/
CREATE   PROC [RDT].[rdtfnc_Capture_HandOverDocExp](
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Session variable
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,
   @cUserName        NVARCHAR( 18),
   @cPrinter         NVARCHAR( 10),
   @cStorerGroup     NVARCHAR( 20),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cSKU             NVARCHAR( 20),
   
   @cHandOverOpt     NVARCHAR( 2),  
   @cHandoverOptName NVARCHAR( 20),     
   @cHandoverKey     NVARCHAR( 20),
   @cToLoc           NVARCHAR( 20),
   @cDocNo           NVARCHAR( 20),
   @cSQL             NVARCHAR( 1000),
   @cSQLParam        NVARCHAR( 1000),
   @cKey2            NVARCHAR( 2),  
         
   @cApptNo          NVARCHAR( 10),
   @cVehicleNo       NVARCHAR( 18),
   @cOption          NVARCHAR( 1),
   @cContainerKey    NVARCHAR( 18), 
   @cWhsRef          NVARCHAR( 18), 
   @cStatus          NVARCHAR( 10),
   @cVehicleDate     NVARCHAR( 18),
   @cTrackingNo      NVARCHAR( 40), 
   @cMenuDisplay     NVARCHAR( 20), --(cc01)
   @cMenuName1       NVARCHAR( 20), --(cc01)
   @cMenuName2       NVARCHAR( 20), --(cc01)
   @cMenuName3       NVARCHAR( 20), --(cc01)
   @cMenuName4       NVARCHAR( 20), --(cc01)
   @cMenuName5       NVARCHAR( 20), --(cc01)
   @cMenuName6       NVARCHAR( 20), --(cc01)
   @cMenuName7       NVARCHAR( 20), --(cc01)
   @cMenuName8       NVARCHAR( 20), --(cc01)
   @cMenuName9       NVARCHAR( 20), --(cc01)
   @cSKUDescr1       NVARCHAR( 20), --(cc01)
   @cSKUDescr2       NVARCHAR( 20), --(cc01)
   @cFromLoc         NVARCHAR( 20), --(cc01)
   @curMenuCur       CURSOR,        --(cc01) 
   @nCnt             INT,           --(cc01)
   @nDocQty          INT,
   @nSkuScan         INT,           --(cc01)
   @nSKUCnt          INT,           --(cc01)
   
   @b_success        INT,
    
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

   @cFacility     = Facility,
   @cPrinter      = Printer,
   @cUserName     = UserName,
   @cStorerKey    = V_StorerKey,
   @cSKU          = V_sku,

   @nDocQty       = V_Integer1,
   @nSkuScan      = V_Integer2,

   @cHandOverOpt  = V_String1,
   @cHandoverKey  = V_String2,
   @cHandoverOptName  = V_String3,
   @cToLoc        = V_String4,
   @cDocNo        = V_String5,
   @cKey2         = V_String6,
   @cMenuName1    = V_String7,   --(cc01)
   @cMenuName2    = V_String8,   --(cc01)
   @cMenuName3    = V_String9,   --(cc01)
   @cMenuName4    = V_String10,  --(cc01)
   @cMenuName5    = V_String11,  --(cc01)
   @cMenuName6    = V_String12,  --(cc01)
   @cMenuName7    = V_String13,  --(cc01)
   @cMenuName8    = V_String14,  --(cc01)
   @cMenuName9    = V_String15,  --(cc01)
      
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

   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06 = FieldAttr06,
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08 = FieldAttr08,
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10 = FieldAttr10,
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12 = FieldAttr12,
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14 = FieldAttr14,
   @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1853
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 1852. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 5900. Handover Opt
   IF @nStep = 2 GOTO Step_2   -- Scn = 5901. DocumentNo
   IF @nStep = 3 GOTO Step_3   -- Scn = 5902. Exit?
   IF @nStep = 4 GOTO Step_4   -- Scn = 5902. SKU
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1853. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
	--load menu
	SET @nCnt = 1 
	SET @curMenuCur = CURSOR FOR   
      SELECT LEFT( RTRIM(Code) + '.' + RTRIM(Description), 20)  
      FROM dbo.CodeLKUP WITH (NOLOCK)   
      WHERE ListName = 'RDTHODocEx'  
         AND StorerKey = @cStorerKey  
      ORDER BY CASE WHEN LEN(code) = 1 THEN '0'+code ELSE  code END
   OPEN @curMenuCur  
   FETCH NEXT FROM @curMenuCur INTO @cMenuDisplay  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @nCnt = 1 SET @cMenuName1 = @cMenuDisplay 
      IF @nCnt = 2 SET @cMenuName2 = @cMenuDisplay  
      IF @nCnt = 3 SET @cMenuName3 = @cMenuDisplay  
      IF @nCnt = 4 SET @cMenuName4 = @cMenuDisplay  
      IF @nCnt = 5 SET @cMenuName5 = @cMenuDisplay  
      IF @nCnt = 6 SET @cMenuName6 = @cMenuDisplay  
      IF @nCnt = 7 SET @cMenuName7 = @cMenuDisplay  
      IF @nCnt = 8 SET @cMenuName8 = @cMenuDisplay  
      IF @nCnt = 9 SET @cMenuName9 = @cMenuDisplay  
  
      SET @nCnt = @nCnt + 1  
      FETCH NEXT FROM @curMenuCur INTO @cMenuDisplay  
   END  
   CLOSE @curMenuCur  
   DEALLOCATE @curMenuCur  
   
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey
      
   -- Prepare next screen var (cc01)  
   SET @cOutField01 = @cMenuName1
   SET @cOutField02 = @cMenuName2
   SET @cOutField03 = @cMenuName3
   SET @cOutField04 = @cMenuName4
   SET @cOutField05 = @cMenuName5
   SET @cOutField06 = @cMenuName6
   SET @cOutField07 = @cMenuName7
   SET @cOutField08 = @cMenuName8
   SET @cOutField09 = @cMenuName9
   SET @cOutField11 = '' -- HandOver Opt
   SET @nDocQty = 0
   SET @nSkuScan = 0

   -- Set the entry point
   SET @nScn = 5900
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5900. Handover Opt
   Option   (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cHandOverOpt = @cInField11

      IF ISNULL(@cHandOverOpt, '') = ''  
      BEGIN  
         SET @nErrNo = 167851  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option  
         GOTO Step_1_Fail  
      END  
  
      IF @cHandOverOpt NOT IN ('1','2','3','4','5','6','7','9','10')  
      BEGIN  
         SET @nErrNo = 167852  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Opt  
         GOTO Step_1_Fail  
      END  
      
      SET @cKey2 = CASE WHEN LEN (@cHandOverOpt) = 1 THEN '0'+ @cHandOverOpt ELSE @cHandOverOpt END
      
      --Opt 1-6 need generate Key1
      IF @cHandOverOpt IN ('1', '2','3','4','5','6')
      BEGIN
      	SET @b_success = 1  
         -- Get new PickDetailkey  
         EXECUTE dbo.nspg_GetKey_AlphaSeq  
            'HandOverDocExceptionNo',  
            10 ,  
            @cHandoverKey  OUTPUT,  
            @b_Success     OUTPUT,  
            @nErrNo        OUTPUT,  
            @cErrMsg       OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SET @nErrNo = 167853  
            SET @cErrMsg = rdt.rdtgetmessage( @cErrMsg, @cLangCode, 'DSP') -- GetKey Fail  
            GOTO Step_1_Fail  
         END 
         
         --SET @cFieldAttr02 = '' --HandoverKey
         SET @cOutField02 = @cHandoverKey--'HandOverNo: ' + @cHandoverKey -- HandOverKey
      END
      ELSE
      BEGIN
      	--SET @cFieldAttr02 = 'O' --HandoverKey
      	SET @cHandoverKey = ''
      	SET @cOutField02 = '' -- HandOverKey
      END      
      
      SET @nDocQty = 0
      --DECLARE @cHandOverOpt1 NVARCHAR(2)
      --SET @cHandOverOpt1 = CONVERT(INT,@cHandOverOpt)+1
      
      --SET @cSQL = 'select @cHandoverOptName = line0'  + @cHandOverOpt1 + ' FROM rdt.rdtscn WITH (NOLOCK) where func = @nFunc and lang_code = @cLangCode and scn = @nScn'    
     
      --   SET @cSQLParam =     
      --      '@cHandoverOptName       nvarchar(20)           OUTPUT, '  +
      --      '@nFunc        INT,           ' +          
      --      '@cLangCode    NVARCHAR( 3),  ' +      
      --      '@nScn         INT '  
              
      --   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
      --        @cHandoverOptName OUTPUT, @nFunc, @cLangCode, @nScn  
      SELECT @cHandoverOptName = LEFT(RTRIM(Description), 20)  
      FROM dbo.CodeLKUP WITH (NOLOCK)   
      WHERE ListName = 'RDTHODocEx'  
         AND StorerKey = @cStorerKey  
         AND code = @cHandOverOpt
         
     
      -- Prepare next screen var
      SET @cOutField01 = @cHandoverOptName -- menuName
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = ''
      SET @cOutField08 = ''  

      EXEC rdt.rdtSetFocusField @nMobile, 3 

      IF @cHandOverOpt NOT IN ('9','10')
      BEGIN
      	--option 1-7 go doc scn
      	SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
      	--option 9-10 go SKU scn
      	SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
     
      GOTO Quit  
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      
      SET @cOutField01 = '' -- menuName
      SET @cOutField02 = '' --HandOverKey
      GOTO Quit
   END   
   GOTO Quit
   
   Step_1_Fail: 
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5901. ToLoc
   MenuName    (field01)
   HandoverKey (field02)
   toLoc       (field03, input)
   DocNo       (field04, input)
   Count       (field05)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLoc = @cInField03 -- ToLoc
      SET @cDocNo = @cInField04 -- DocNo

      -- Check ToLoc blank
      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 167854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToLoc
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- toLoc  
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND Loc = @cToLoc)
      BEGIN
      	SET @nErrNo = 167861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToLoc
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- toLoc  
         GOTO Step_2_Fail
      END
      
      -- Check DocNo blank
      IF @cDocNo = ''
      BEGIN
         SET @nErrNo = 167855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DocNo
         --SET @cInField03 = @cToLoc  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- DocNo
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE storerKey = @cStorerKey AND DocumentNo = @cDocNo AND TableName = 'asnexception')
      BEGIN
      	SET @nErrNo = 167862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DocNo
         GOTO Step_2_Fail
      END      
      
      IF EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE storerKey = @cStorerKey AND DocumentNo = @cDocNo AND key2 = @cKey2)
      BEGIN
      	SET @nErrNo = 167856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DocNo Exists
         GOTO Step_2_Fail
      END
      ELSE
      BEGIN
      	INSERT INTO DocStatusTrack (TableName,DocumentNo,Key1,Key2,DocStatus,TransDate,Userdefine04,AddWho,AddDate,EditWho,EditDate,StorerKey)
      	VALUES ('EXCEPTIONRDT', @cDocNo, @cHandoverKey, @cKey2, '1', GETDATE(), @cToLoc, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE(),@cStorerKey)
      	
      	IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 167857  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Fail  
            GOTO Step_2_Fail  
         END  
      END	
      
      --SELECT @nDocQty = COUNT(RowRef) FROM DocStatusTrack WITH (NOLOCK) WHERE storerKey = @cStorerKey AND Userdefine04 = @cToLoc AND key1 = @cHandoverKey
      SET @nDocQty += 1
      
      --IF @cHandOverOpt = '7'
      --BEGIN
      --	SET @cFieldAttr02 = 'O' --HandoverKey
      --END
      	      
      -- loop current screen
      SET @cOutField01 = @cHandoverOptName -- menuName
      SET @cOutField02 = @cHandoverKey--CASE WHEN @cHandOverOpt = '7' THEN '' ELSE 'HandOverNo: ' +  @cHandoverKey END -- HandOverKey
      SET @cOutField03 = @cToLoc -- ToLoc
      SET @cOutField04 = '' -- DocNo
      SET @cOutField05 = @nDocQty -- DocNo
      
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- DocNo
      
      GOTO Quit  
      
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Init next screen var
      SET @cOutField01 = @cHandoverOptName -- menuName
      SET @cOutField02 = @cHandoverKey--CASE WHEN @cHandOverOpt = '7' THEN '' ELSE 'HandOverNo: ' +  @cHandoverKey END -- HandOverKey
      SET @cOutField03 = @cToLoc -- ToLoc
      SET @cOutField04 = @nDocQty -- Count
      SET @cOutField05 = '' -- Option
            
      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit  
   
   Step_2_Fail: 
   SET @cOutField03 = @cToLoc -- ToLoc
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 5902. Exit?
   MenuName    (field01)
   HandOverKey (field02)
   ToLoc       (field03)
   Count       (field04)
   OPTION      (field05, input)
********************************************************************************/
Step_3:
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField05  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 167858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option  
         GOTO Step_3_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 167859  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Opt  
         GOTO Step_3_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN    
      	UPDATE DocStatusTrack WITH (ROWLOCK) SET docStatus = '9' WHERE StorerKey = @cStorerKey AND Addwho = SUSER_SNAME() AND tableName = 'EXCEPTIONRDT' AND DocStatus = '1'
      	
      	IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 167860  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd Fail  
            GOTO Step_3_Fail  
         END  
         
         --(cc01)
         SET @cOutField01 = @cMenuName1
         SET @cOutField02 = @cMenuName2
         SET @cOutField03 = @cMenuName3
         SET @cOutField04 = @cMenuName4
         SET @cOutField05 = @cMenuName5
         SET @cOutField06 = @cMenuName6
         SET @cOutField07 = @cMenuName7
         SET @cOutField08 = @cMenuName8
         SET @cOutField09 = @cMenuName9
         SET @cOutField11 = '' -- HandOver Opt
        
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2  
  
         GOTO Quit  
      END  
   END  
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cHandoverOptName
      SET @cOutField02 = @cHandoverKey 
      SET @cOutField03 = '' --TOLOC
      SET @cOutField04 = '' --DocNo

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END   
   GOTO Quit  
   
   Step_3_Fail:
END  
GOTO Quit  

/********************************************************************************
Step 4. Scn = 5903. SKU
   MenuName    (field01)
   Loc         (field02, input)
   SKU         (field03, input)
   PrevSku     (field04)
   SKUDescr1   (field05)
   SKUDescr2   (field06)
   DocumentNo  (field07)
   Count       (field08)
********************************************************************************/
Step_4:
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cFromLoc = @cInField02  
      SET @cSKU = @cInField03  
      
      IF ISNULL(@cFromLoc, '') = ''  
      BEGIN
      	SET @nErrNo = 167863  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Loc  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- FromLoc
         GOTO QUIT  
      END
      
      IF NOT EXISTS (SELECT 1 FROM Loc WITH (NOLOCK) WHERE LOC = @cFromLoc)
      BEGIN
      	SET @nErrNo = 167864  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Loc  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- FromLoc
         GOTO QUIT  
      END
      
      IF ISNULL(@cSKU, '') = ''  
      BEGIN  
         SET @nErrNo = 167865  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU  
         GOTO Step_4_Fail  
      END  
      
       -- Get SKU barcode count  
      SET @nSKUCnt = 0  
  
      EXEC rdt.rdt_GETSKUCNT  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU  
         ,@nSKUCnt     = @nSKUCnt       OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @nErrNo        OUTPUT  
         ,@cErrMsg     = @cErrMsg       OUTPUT  
  
  
      -- Check SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 167866  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU  
         GOTO Step_4_Fail  
      END
      
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 167867  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod  
         GOTO Step_4_Fail  
      END 
      
      -- Get SKU code  
      EXEC rdt.rdt_GETSKU  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU          OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @nErrNo        OUTPUT  
         ,@cErrMsg     = @cErrMsg       OUTPUT  
         
      SELECT 
         @cSKUDescr1 = SUBSTRING ( Descr ,1 , 20 ) ,
         @cSKUDescr2 = SUBSTRING ( Descr ,21 , 40 ) 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
  
      IF @cKey2 = '09' 
      BEGIN
      	SET @b_success = 1  
         -- Get new PickDetailkey  
         EXECUTE dbo.nspg_GetKey_AlphaSeq  
            'HandOverDocExceptionNo',  
            10 ,  
            @cHandoverKey  OUTPUT,  
            @b_Success     OUTPUT,  
            @nErrNo        OUTPUT,  
            @cErrMsg       OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SET @nErrNo = 167868  
            SET @cErrMsg = rdt.rdtgetmessage( @cErrMsg, @cLangCode, 'DSP') -- GetKey Fail  
            GOTO Step_4_Fail  
         END 
         
      	INSERT INTO DocStatusTrack (TableName,DocumentNo,Key1,Key2,DocStatus,TransDate,Userdefine03,AddWho,AddDate,EditWho,EditDate,StorerKey,Finalized, Userdefine04)
      	VALUES ('EXCEPTIONRDT', @cHandoverKey, @cSKU, @cKey2, '0', GETDATE(), '1', SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE(),@cStorerKey,'N', @cFromLoc)
      	
      	IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 167869  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Fail  
            GOTO Step_4_Fail  
         END  	
      END
      
      IF @cKey2 = '10' 
      BEGIN
      	IF EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) 
      	           WHERE StorerKey = @cStorerKey 
      	           AND Key1 = @cSKU 
      	           AND Finalized = 'N' 
      	           AND DocStatus = '0' 
      	           AND key2 = '09')
      	BEGIN
      		IF EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) 
      		           WHERE StorerKey = @cStorerKey 
      		           AND Key1 = @cSKU 
      		           AND Finalized = 'N' 
      		           AND DocStatus = '0' 
      		           AND key2 = '09' 
      		           AND Userdefine04 = @cFromLoc)
            BEGIN
            	SELECT TOP 1
      		      @cHandoverKey = DocumentNo
      		   FROM DocStatusTrack WITH (NOLOCK)
      		   WHERE StorerKey = @cStorerKey
      		   AND KEY1 = @cSKU
      		   AND DocStatus = '0'
      		   AND Finalized = 'N'
      		   AND Userdefine04 = @cFromLoc
      		
      		   UPDATE DocStatusTrack SET
      		      docStatus = '9',
      		      Finalized = 'Y'
      		   WHERE StorerKey = @cStorerKey
      		   AND KEY1 = @cSKU
      		   AND DocStatus = '0'
      		   AND Finalized = 'N'
      		   AND DocumentNo = @cHandoverKey
            END
            ELSE
            BEGIN
            	SET @nErrNo = 167870  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Loc  
               GOTO Step_4_Fail 
            END
      	END
      	ELSE
      	BEGIN
      		SET @nErrNo = 167871  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Sku  
            GOTO Step_4_Fail  
      	END
      END
      
      SET @nSkuScan = @nSkuScan + 1
      
      
      SET @cOutField01 = @cHandoverOptName
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = '' --sku 
      SET @cOutField04 = @cSKU
      SET @cOutField05 = @cSKUDescr1
      SET @cOutField06 = @cSKUDescr2
      SET @cOutField07 = @cHandoverKey
      SET @cOutField08 = @nSkuScan
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
   END
      
   
   IF @nInputKey = 0 -- ESC
   BEGIN
   	SET @nSkuScan = 0
   	
      -- Prepare prev screen var
      SET @cOutField01 = @cMenuName1
      SET @cOutField02 = @cMenuName2
      SET @cOutField03 = @cMenuName3
      SET @cOutField04 = @cMenuName4
      SET @cOutField05 = @cMenuName5
      SET @cOutField06 = @cMenuName6
      SET @cOutField07 = @cMenuName7
      SET @cOutField08 = @cMenuName8
      SET @cOutField09 = @cMenuName9
      SET @cOutField11 = '' -- HandOver Opt

      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END   
   GOTO Quit  
   
   Step_4_Fail:
      SET @cOutField01 = @cHandoverOptName
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = ''
      SET @cOutField04 = @cSKUDescr1
      SET @cOutField05 = @cSKUDescr2
      SET @cOutField06 = @cHandoverKey
      SET @cOutField07 = @nSkuScan
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
END  
GOTO Quit  

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility     = @cFacility,
      Printer      = @cPrinter,
      V_StorerKey  = @cStorerKey, 
      V_sku        = @cSKU,

      V_Integer1    = @nDocQty,
      V_Integer2    = @nSkuScan,

      V_String1    = @cHandOverOpt,
      V_String2    = @cHandoverKey,
      V_String3    = @cHandoverOptName,
      V_String4    = @cToLoc,
      V_String5    = @cDocNo,
      V_String6    = @cKey2,
      V_String7    = @cMenuName1, --(cc01)
      V_String8    = @cMenuName2, --(cc01)
      V_String9    = @cMenuName3, --(cc01)
      V_String10   = @cMenuName4, --(cc01)
      V_String11   = @cMenuName5, --(cc01)
      V_String12   = @cMenuName6, --(cc01)
      V_String13   = @cMenuName7, --(cc01)
      V_String14   = @cMenuName8, --(cc01)
      V_String15   = @cMenuName9, --(cc01)
 
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
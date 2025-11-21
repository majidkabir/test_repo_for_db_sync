SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_ReturnUnloading                                    */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Return Unloading                                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2021-02-17   1.0  Chermaine   WMS-16332. Created                           */
/* 2021-05-03   1.1  Chermaine   WMS-16945 Add eventlog (cc01)                */
/* 2022-02-16   1.2  Ung         WMS-18908 Add TransmitLog                    */
/* 2022-11-06   1.3  YeeKung     WMS-21120 Chang Mapping (yeekung01)          */ 
/* 2023-02-15   1.4  YeeKung     WMS-21762 add mapping (yeekung02)            */ 
/******************************************************************************/
CREATE   PROC [RDT].[rdtfnc_ReturnUnloading](
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @nRowCount        INT,
   @b_success        INT

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
                     
   @cApptNo          NVARCHAR( 10),
   @cVehicleNo       NVARCHAR( 18),
   @cOption          NVARCHAR( 1),
   @cContainerKey    NVARCHAR( 18), 
   @cWhsRef          NVARCHAR( 18), 
   @cStatus          NVARCHAR( 10),
   @cVehicleDate     NVARCHAR( 18),
   @cMissingTRITF    NVARCHAR( 1), 
   @cTrackingNo      NVARCHAR( 40), 
   @cReceiptKey      NVARCHAR( 10),  --(cc01)
   @nFromScn         INT,
   @nFromStep        INT,
   @nParcelQty       INT,
    
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

   @nParcelQty    = V_Integer1,
   @nFromScn      = V_Integer2,
   @nFromStep     = V_Integer3,

   @cApptNo       = V_String1,
   @cVehicleNo    = V_String2,
   @cOption       = V_String3,
   @cContainerKey = V_String4,
   @cWhsRef       = V_String5,
   @cStatus       = V_String6,
   @cVehicleDate  = V_String7,
   
   @cMissingTRITF = V_String20, 
   
   @cTracKingNo   = V_String41,
   
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
IF @nFunc = 1852
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 1852. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 5880. ApptNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 5881. SealNo
   IF @nStep = 3 GOTO Step_3   -- Scn = 5882. Return Type Option
   IF @nStep = 4 GOTO Step_4   -- Scn = 5883. BagNo,AWB
   IF @nStep = 5 GOTO Step_5   -- Scn = 5884. Seal Complete?
   IF @nStep = 6 GOTO Step_6   -- Scn = 5885. BagNo,TrackingNo
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1852. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Storer configure
   SET @cMissingTRITF = rdt.RDTGetConfig( @nFunc, 'MissingTradeReturnITF', @cStorerKey)
   
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey
      
   -- Prepare next screen var
   SET @cOutField01 = '' -- ApptNo
   SET @nParcelQty = 0

   -- Set the entry point
   SET @nScn = 5880
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5880. ApptNo Screen
   ApptNo   (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cApptNo = @cInField01

      -- Generate ApptNo
      IF @cApptNo = '' 
      BEGIN
         SET @b_success = 1  
         -- Get new PickDetailkey  
         EXECUTE dbo.nspg_GetKey  
            'ApptNo',  
            10 ,  
            @cApptNo     OUTPUT,  
            @b_Success   OUTPUT,  
            @nErrNo     OUTPUT,  
            @cErrMsg    OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SET @nErrNo = 163401  
            SET @cErrMsg = rdt.rdtgetmessage( @cErrMsg, @cLangCode, 'DSP') -- GetKey Fail  
            GOTO Quit  
         END  
      END
      
      SET @nParcelQty = 0
      
      -- Prepare next screen var
      SET @cOutField01 = @cApptNo -- ApptNo
      SET @cOutField02 = '' -- SealNo

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
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
      
      SET @cOutField01 = '' -- ApptNo

      SET @cOutField01 = ''
      GOTO Quit
   END   
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5881. SealNo Screen
   ApptNo   (field01)
   SealNo   (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cVehicleNo = @cInField02 -- SealNo

      -- Check SealNo blank
      IF @cVehicleNo = ''
      BEGIN
         SET @nErrNo = 163402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SealNo
         GOTO Quit
      END
      
      -- Init next screen var
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --@cOption
      
      -- Go to next screen
      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''--ApptNo

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 5882. Return Type Option Screen
   ApptNo   (field01)
   SealNo   (field02)
   Option   (field03, input) --1.DTO/MYNTRA,2.HM-RTO
********************************************************************************/
Step_3:
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField03  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 163403  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option  
         GOTO Quit  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 163404  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Opt  
         GOTO Quit  
      END  
  
      IF @cOption = '1'  
      BEGIN    
         SET @cOutField01 = @cApptNo
         SET @cOutField02 = @cVehicleNo 
         SET @cOutField03 = '' --BagNo   
         SET @cOutField04 = '' --AWB
         
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
  
         GOTO Quit  
      END  
      ELSE  
      BEGIN  
         SET @cOutField01 = @cApptNo
         SET @cOutField02 = @cVehicleNo 
         SET @cOutField03 = '' --BagNo   
         SET @cOutField04 = '' --TrackingNo
         
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 3  
         SET @nStep = @nStep + 3  
  
         GOTO Quit  
      END  
   END  
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cApptNo
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --Option

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END   
END  
GOTO Quit  

/********************************************************************************
Step 4. Scn = 5883. BagNo,AWB Screen
   ApptNo   (field01)
   SealNo   (field02)
   BagNo    (field03, input)
   AWB      (field04, input)
   ParcelQty(field05)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cContainerKey = @cInField03 -- BagNo
      SET @cWhsRef       = @cInField04 -- AWB
      
      -- Check BagNo blank
      IF @cContainerKey = ''
      BEGIN
         SET @nErrNo = 163405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Bag No
         GOTO step_4_fail
      END
      
      -- Check AWB blank
      IF @cWhsRef = ''
      BEGIN
         SET @nErrNo = 163406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need AWB
         GOTO step_4_fail
      END
      
      SELECT 
          @cStatus = STATUS,
          @cReceiptKey = ReceiptKey  --(cc01)
      FROM dbo.RECEIPT  WITH (NOLOCK) 
      WHERE storerKey = @cStorerKey 
      AND (WarehouseReference = @cWhsRef OR trackingno = @cWhsRef) --(yeekung02)
      AND doctype = 'R'
      
      SET @nRowCount = @@ROWCOUNT 
      
      IF @nRowCount = 0 
      BEGIN
         IF @cMissingTRITF = '1'
         BEGIN
            EXEC dbo.ispGenTransmitLog2 'WSRDTMISSDR', @cApptNo, @cWhsRef, @cStorerKey, ''
               , @b_Success OUTPUT
               , @nErrNo    OUTPUT
               , @cErrMsg   OUTPUT
            IF @b_Success = 0  
            BEGIN  
               SET @nErrNo = 163420  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS TLog2 Fail'  
               GOTO step_4_fail 
            END  
         END
         
      	SET @nErrNo = 163407
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AWB Not Exist
         GOTO step_4_fail
      END
      
      IF @nRowCount > 1 
      BEGIN
      	SET @nErrNo = 163408
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid AWB  
         GOTO step_4_fail
      END
      
      IF @cStatus <> '0'
      BEGIN
      	SET @nErrNo = 163409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StatusNotOpen  
         GOTO step_4_fail
      END
      
      SET @cVehicleDate = CONVERT(NVARCHAR(18),GETDATE(),120)--CONVERT(NVARCHAR(8),GETDATE(),112)+' '+CONVERT(NVARCHAR(8),GETDATE(),114)
      
      UPDATE dbo.RECEIPT WITH (ROWLOCK) SET
         Appointment_No = @cApptNo,
         VehicleDate = @cVehicleDate,
         VehicleNumber = @cVehicleNo,
         Containerkey = @cContainerKey
      WHERE storerKey = @cStorerKey 
      AND (WarehouseReference = @cWhsRef OR trackingno = @cWhsRef) --(yeekung02)
      AND doctype = 'R'
      AND STATUS = '0'
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 163410  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReceiptFail'  
         GOTO step_4_fail 
      END  
      
      --SET @nParcelQty = @nParcelQty +1
      
      SELECT  @nParcelQty = COUNT(ReceiptKey)
      FROM Receipt(NOLOCK)
      WHERE Storerkey= @cStorerKey
      AND DOCTYPE='R'
      AND Appointment_no = @cApptNo
      AND VehicleNumber = @cVehicleNo
      
      -- EventLog  --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '2',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cReceiptKey = @cReceiptKey
      
      --Print
      --DECLARE @tPrintMani AS VariableTable  
      --DELETE FROM @tPrintMani
      --INSERT INTO @tPrintMani (Variable, Value) VALUES ( '@cApptNo', @cApptNo)  
              
      ---- Print Manifest  
      --EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,   
      --   'LGPALLETLB', -- Report type  
      --   @tPrintMani, -- Report params  
      --   'rdtfnc_ReturnUnloading',   
      --   @nErrNo  OUTPUT,  
      --   @cErrMsg OUTPUT     
      
      -- Init current screen var
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --bagNo
      SET @cOutField04 = '' --AWB
      SET @cOutField05 = @nParcelQty
      
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare Next screen var
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --option

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
      
      GOTO Quit
   END
   
   Step_4_fail:
   BEGIN
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = @cContainerKey
      EXEC rdt.rdtSetFocusField @nMobile, 4 --@cWhsRef
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 5884. Seal Complete? Screen
   ApptNo   (field01)
   SealNo   (field02)
   Option   (field03, input)
********************************************************************************/
Step_5:
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField03  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 163411  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option  
         GOTO Quit  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 163412  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Opt  
         GOTO Quit  
      END  
      
      IF @cOption = '1'  
      BEGIN   
      	--back to sealNo screen
      	SET @cOutField01 = @cApptNo
         SET @cOutField02 = '' --sealNo 
            
         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 3  
      	
         GOTO Quit  
      END  
      ELSE  
      BEGIN   
      	SET @cOutField01 = @cApptNo
         SET @cOutField02 = @cVehicleNo 
         SET @cOutField03 = '' --BagNo   
         SET @cOutField04 = '' --TrackingNo/AWB
            
         SET @nScn = @nFromScn  
         SET @nStep = @nFromStep  

         GOTO Quit  
      END  
   END   
END  
GOTO Quit  

/********************************************************************************
Step 6. Scn = 5885. BagNo,TrackingNo Screen
   ApptNo   (field01)
   SealNo   (field02)
   BagNo    (field03, input)
   TrackingNo (field04, input)
   QTY      (field05)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cContainerKey = @cInField03 -- BagNo
      SET @cTrackingNo   = @cInField04 -- TrackingNo

      -- Check BagNo blank
      IF @cContainerKey = ''
      BEGIN
         SET @nErrNo = 163413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Bag No
         GOTO step_6_fail
      END
      
      -- Check AWB blank
      IF @cTrackingNo = ''
      BEGIN
         SET @nErrNo = 163414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedTrackingNo
         GOTO step_6_fail
      END
           
      DECLARE @nArchiveDB INT
      SET @nArchiveDB = 0
         
      SELECT 
          @cStatus = STATUS
      FROM dbo.ORDERS  WITH (NOLOCK) 
      WHERE storerKey = @cStorerKey 
      AND TrackingNo = @cTrackingNo
      AND doctype <> 'R'
      
      IF @@ROWCOUNT = 0 
      BEGIN
         SELECT 
             @cStatus = STATUS
         FROM INARCHIVE.dbo.ORDERS  WITH (NOLOCK) 
         WHERE storerKey = @cStorerKey 
         AND TrackingNo = @cTrackingNo
         AND doctype <> 'R'
         
         IF @@ROWCOUNT = 0 
         BEGIN
      	   SET @nErrNo = 163415
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotExist
            GOTO step_6_fail
         END
         
         SET @nArchiveDB = 1
      END
      
      IF @cStatus <> '9'
      BEGIN
      	SET @nErrNo = 163416
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RTO  
         GOTO step_6_fail
      END
      
       DECLARE  
       	@cNewReceiptKey   NVARCHAR(10), 
         @cExternOrderKey  NVARCHAR(50),  
         @cOrderKey        NVARCHAR(10),  
         @cBuyerPO         NVARCHAR(20),
         @cUserDefine03    NVARCHAR(30),
         @cOrderType       NVARCHAR(10),
         @nOpenQty         INT,
         @cBizUnit         NVARCHAR(20),
         @cStoreName       NVARCHAR(20),
         @cTOLoc           NVARCHAR(20)
      
      IF @nArchiveDB = 1
      BEGIN
      	SELECT 
            @cExternOrderKey = ExternOrderKey,
            @cOrderKey = OrderKey,
            @cBuyerPO = Buyerpo,
            @cOrderType = TYPE, 
            @cBizUnit = BizUnit --(yeekung01)
         FROM INARCHIVE.dbo.ORDERS O WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND TrackingNo = @cTrackingNo
         AND DocType <> 'R'
         AND STATUS = '9'
         AND addDate < DATEADD(MONTH, 7, GETDATE())
      
         SELECT @nOpenQty = SUM(ShippedQty) 
         FROM INARCHIVE.dbo.OrderDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND orderKey = @cOrderKey

         SELECT @cStoreName=StoreName --(yeekung01)
         FROM INARCHIVE.dbo.OrderInfo WITH (NOLOCK)          
         WHERE  orderKey = @cOrderKey



         SELECT Top 1 @cUserDefine03 = UDF04 
         FROM CODELKUP WITH (NOLOCK) 
         WHERE @cStorerKey = @cStorerKey 
            AND listName = 'HMORDTYPE' 
            AND code = @cOrderType
         
         --SELECT Top 1 @cUserDefine03 = LK.UDF04 
         --FROM CODELKUP LK WITH (NOLOCK) 
         --INNER JOIN INARCHIVE.dbo.ORDERS O WITH (NOLOCK) ON (O.TYPE = LK.Code AND O.StorerKey = LK.Storerkey)
         --WHERE LK.LISTNAME ='HMORDTYPE' 
         --AND LK.Storerkey= @cStorerKey
         --AND O.TrackingNo = @cTrackingNo
         --ORDER BY O.Orderkey DESC
      END
      ELSE
      BEGIN
      	SELECT 
            @cExternOrderKey = ExternOrderKey,
            @cOrderKey = OrderKey,
            @cBuyerPO = Buyerpo,
             @cBizUnit = BizUnit --(yeekung01)
         FROM ORDERS WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND TrackingNo = @cTrackingNo
         AND DocType <> 'R'
         AND STATUS = '9'
      
         SELECT @nOpenQty = SUM(ShippedQty) 
         FROM OrderDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND orderKey = @cOrderKey

        SELECT @cStoreName=StoreName --(yeekung01)
         FROM dbo.OrderInfo WITH (NOLOCK)          
         WHERE  orderKey = @cOrderKey
                  
         SELECT Top 1 @cUserDefine03 = LK.UDF04 
         FROM CODELKUP LK WITH (NOLOCK) 
         INNER JOIN ORDERS O WITH (NOLOCK) ON (O.TYPE = LK.Code AND O.StorerKey = LK.Storerkey)
         WHERE LK.LISTNAME ='HMORDTYPE' 
         AND LK.Storerkey= @cStorerKey
         AND O.TrackingNo = @cTrackingNo
         ORDER BY O.Orderkey DESC
      END

      SELECT @cToloc=code  --(yeekung01)
      FROM codelkup (NOLOCK)
      WHERE listname = 'HMRETLOC' 
         AND long  = @cFacility
         AND storerkey=@cStorerKey
      
      SET @cVehicleDate = CONVERT(NVARCHAR(18),GETDATE(),120)--CONVERT(NVARCHAR(8),GETDATE(),112)+' '+CONVERT(NVARCHAR(8),GETDATE(),114)
          
      IF NOT EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND (WarehouseReference = @cTrackingNo OR CarrierState =  @cTrackingNo ))
      BEGIN
      	-- Get next receipt key  
         SELECT @b_success = 0  
         EXECUTE nspg_getkey  
            'RECEIPT',
            10,  
            @cNewReceiptKey   OUTPUT,  
            @b_Success        OUTPUT,  
            @nErrNo           OUTPUT,  
            @cErrMsg          OUTPUT  
         IF @b_Success <> 1  
         BEGIN  
            SET @nErrNo = 163417  
            SET @cErrMsg = rdt.rdtgetmessage( @cErrMsg, @cLangCode, 'DSP') -- GenRecKeyFail  
            GOTO step_6_fail  
         END   
         
         INSERT INTO RECEIPT 
            (ReceiptKey, ExternReceiptKey, StorerKey, CarrierState, WarehouseReference, 
            VehicleNumber, VehicleDate,Containerkey, OpenQty, RECType, 
            Facility, Appointment_No, DOCTYPE, ASNReason,UserDefine04,SellerName)  
         VALUES 
            (@cNewReceiptKey, @cExternOrderKey, @cStorerKey, @cTrackingNo, @cTrackingNo, 
            @cVehicleNo, @cVehicleDate, @cContainerKey, 0, 'HM_F', 
            @cFacility, @cApptNo, 'R', '12',@cBuyerPO,@cBizUnit) --(yeekung01)
          
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 163422  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD Rec Fail  
            GOTO step_6_fail  
         END     
      END
      ELSE
      BEGIN
      	SELECT @cNewReceiptKey = ReceiptKey FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND (WarehouseReference = @cTrackingNo OR CarrierState =  @cTrackingNo)

         UPDATE Receipt WITH (ROWLOCK)--(yeekung01)
         set UserDefine04= @cBuyerPO,
            SellerName =@cBizUnit
         WHERE receiptkey=@cNewReceiptKey

                   
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 163418  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS Rec Fail  
            GOTO step_6_fail  
         END     
      END
      
      IF NOT EXISTS (SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cNewReceiptKey ) 
      BEGIN   
      	IF @nArchiveDB = 1
      	BEGIN
      		IF EXISTS ( SELECT 1
                  FROM INARCHIVE.dbo.OrderDetail OD WITH (NOLOCK) 
                  JOIN INARCHIVE.dbo.PICKDETAIL PD WITH (NOLOCK) ON (OD.StorerKey = PD.Storerkey AND OD.OrderKey = PD.OrderKey AND PD.SKU = OD.SKU AND PD.orderLineNumber = OD.OrderLineNumber)
                  JOIN LOTATTRIBUTE LOT WITH (NOLOCK) ON (LOT.Lot = PD.Lot)
                  WHERE OD.StorerKey = @cStorerKey 
                  AND OD.OrderKey = @cOrderKey)
            BEGIN
            	INSERT INTO ReceiptDetail (
                  ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, 
                  SKU, STATUS, QtyExpected, UOM, PackKey, 
                  VoyageKey, ToLoc, Lottable01, Lottable02, Lottable03, SubReasonCode,  
                  ExternPoKey, UserDefine03, UserDefine08, UserDefine09, Lottable12)                   
               SELECT 
                  @cNewReceiptKey, OD.OrderLineNumber, @cExternOrderKey, OD.ExternLineNo, @cStorerKey, 
                  OD.SKU, '0', PD.QTY, OD.UOM, OD.PackKey,  
                  @cTrackingNo, @cToloc, ISNULL(Lot.Lottable01,''), ISNULL(Lot.Lottable02,''), 'RET', 'NULL', 
                  @cBuyerPO, @cUserDefine03, @cBuyerPO, OD.ExternLineNo ,ISNULL(Lot.Lottable12,'')
               FROM INARCHIVE.dbo.OrderDetail OD WITH (NOLOCK) 
               JOIN INARCHIVE.dbo.PICKDETAIL PD WITH (NOLOCK) ON (OD.StorerKey = PD.Storerkey AND OD.OrderKey = PD.OrderKey AND PD.SKU = OD.SKU AND PD.orderLineNumber = OD.OrderLineNumber)
               JOIN LOTATTRIBUTE LOT WITH (NOLOCK) ON (LOT.Lot = PD.Lot)
               WHERE OD.StorerKey = @cStorerKey 
               AND OD.OrderKey = @cOrderKey

            END
      	END
      	ELSE
         BEGIN
         	INSERT INTO ReceiptDetail (
               ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, 
               SKU, STATUS, QtyExpected, UOM, PackKey, 
               VoyageKey, ToLoc, Lottable01, Lottable02, Lottable03, SubReasonCode,  
               ExternPoKey, UserDefine03, UserDefine08, UserDefine09, Lottable12)                   
            SELECT 
               @cNewReceiptKey, OD.OrderLineNumber, @cExternOrderKey, OD.ExternLineNo, @cStorerKey, 
               OD.SKU, '0', PD.QTY, OD.UOM, OD.PackKey,  
               @cTrackingNo, @cToloc, Lot.Lottable01, Lot.Lottable02, 'RET', 'NULL', 
               @cBuyerPO, @cUserDefine03, @cBuyerPO, OD.ExternLineNo ,Lot.Lottable12
            FROM OrderDetail OD WITH (NOLOCK) 
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OD.StorerKey = PD.Storerkey AND OD.OrderKey = PD.OrderKey AND PD.SKU = OD.SKU AND PD.orderLineNumber = OD.OrderLineNumber)
            JOIN LOTATTRIBUTE LOT WITH (NOLOCK) ON (LOT.Lot = PD.Lot)
            WHERE OD.StorerKey = @cStorerKey 
            AND OD.OrderKey = @cOrderKey


         END
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 163419  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSRecDtFail  
            GOTO step_6_fail  
         END    

         INSERT INTO ReceiptInfo (receiptkey,StoreName) --(yeekung01)
         VALUES(@cNewReceiptKey,@cStoreName)

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 163423  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSRecDtFail  
            GOTO step_6_fail  
         END    
      END      
      
      --SET @nParcelQty = @nParcelQty +1
      
      SELECT  @nParcelQty = COUNT(ReceiptKey)
      FROM Receipt(NOLOCK)
      WHERE Storerkey= @cStorerKey
      AND DOCTYPE='R'
      AND Appointment_no = @cApptNo
      AND VehicleNumber = @cVehicleNo
      
      -- EventLog  --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '2',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cReceiptKey = @cNewReceiptKey
      
      -- Init current screen var
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --bagNo
      SET @cOutField04 = '' --TrackingNo
      SET @cOutField05 = @nParcelQty
      
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare Next screen var
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = '' --option

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
      
      GOTO Quit
   END
   
   Step_6_fail:
   BEGIN
      SET @cOutField01 = @cApptNo 
      SET @cOutField02 = @cVehicleNo 
      SET @cOutField03 = @cContainerKey
      EXEC rdt.rdtSetFocusField @nMobile, 4 --@cWhsRef
   END
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

      V_Integer1    = @nParcelQty,
      V_Integer2    = @nFromScn,
      V_Integer3    = @nFromStep,

      V_String1    = @cApptNo,
      V_String2    = @cVehicleNo,
      V_String3    = @cOption,
      V_String4    = @cContainerKey,
      V_String5    = @cWhsRef,
      V_String6    = @cStatus,
      V_String7    = @cVehicleDate,

      V_String20   = @cMissingTRITF,

      V_String41   = @cTracKingNo,

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
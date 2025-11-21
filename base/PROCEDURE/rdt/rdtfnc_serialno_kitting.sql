SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/******************************************************************************/       
/* Copyright: LF                                                              */       
/* Purpose:                                                                   */       
/*                                                                            */       
/* Modifications log:                                                         */       
/*                                                                            */       
/* Date       Rev  Author     Purposes                                        */       
/* 2017-07-26 1.0  ChewKP     Created. WMS-1931                               */  
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_SerialNo_Kitting] (      
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
         
   @nError            INT,      
   @b_success         INT,      
   @n_err             INT,           
   @c_errmsg          NVARCHAR( 250),       
   @cPUOM             NVARCHAR( 10),          
   @bSuccess          INT,      
   @cDataWindow		 NVARCHAR( 50),  
   @cTargetDB    		 NVARCHAR( 20), 
   @cWorkOrderNo      NVARCHAR( 10),
   @cFromSKUInput     NVARCHAR( 20),   
   @cToSKUInput       NVARCHAR( 20),   
   @cSerialNo         NVARCHAR( 20),
   @nSKUCnt           INT,
   @cFromSKU          NVARCHAR( 20),
   @cToSKU            NVARCHAR( 20), 
   @cBatchKey         NVARCHAR( 10),
   @n9LQty            INT,
   @nInnerQty         INT,
   @nMasterQty        INT,
   @c9LNewLabel       NVARCHAR(1),
   @cInnerNewLabel    NVARCHAR(1),
   @cMasterNewLabel   NVARCHAR(1),
   @n9LCount          INT,
   @cToSerialNo       NVARCHAR(20),
   @nInnerCount       INT,
   @nMasterCount      INT,
   @nRowRef           INT,
   @cFromSerialNo     NVARCHAR(20),
   @cParentSerialNo   NVARCHAR(20),
   @cInnerSerialNo    NVARCHAR(20),
   @cMasterSerialNo   NVARCHAR(20), 
   @nMasterSerialNoKey INT,
   @cSKU              NVARCHAR(20),
   @cSKUInput         NVARCHAR(20),
   @c9LSerialNo       NVARCHAR(20),
   @cRemarks          NVARCHAR(20),
   @cGenSerialSP      NVARCHAR(30),
   @cSQL              NVARCHAR(1000), 
   @cSQLParam         NVARCHAR(1000), 
   @cPrinter9L        NVARCHAR( 20),      
   @cPrinterInner     NVARCHAR( 20),      
   @cPrinterMaster    NVARCHAR( 20),      
   @cPrinterGTIN      NVARCHAR( 20),
   @cStatus           NVARCHAR( 10),
   @cLocationCode     NVARCHAR( 10),
   @nMasterUnitQty    INT,
   @cOption           NVARCHAR(1),
   --@nMasterQty        INT,
   @cGenerateLabel    NVARCHAR(1),
   @cWorkOrderSKU     NVARCHAR(20),
   @cPackKey          NVARCHAR(10),
   @nInnerPack        INT,
   @nCaseCnt          INT,
   @cSerialType       NVARCHAR(1),
   @cChildSerialNo    NVARCHAR(20),
   @cPassed           NVARCHAR(1),
   @nScanCount        INT,
   @nCLabelQty        INT,
   @cOriginalParentSerialNo NVARCHAR(20),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
            
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


DECLARE @tMasterSerialTemp TABLE (
            --	[MasterSerialNoKey] [bigint] IDENTITY(1,1) NOT NULL,
            	[LocationCode] [nvarchar](10) NULL DEFAULT (''),
            	[UnitType] [nvarchar](10) NULL DEFAULT (''),
            	[PartnerType] [nvarchar](20) NULL DEFAULT (''),
            	[SerialNo] [nvarchar](50) NOT NULL DEFAULT (''),
            	[ElectronicSN] [nvarchar](50) NULL DEFAULT (''),
            	[Storerkey] [nvarchar](15) NOT NULL DEFAULT (''),
            	[Sku] [nvarchar](20) NOT NULL DEFAULT (''),
            	[ItemID] [nvarchar](50) NULL DEFAULT (''),
            	[ItemDescr] [nvarchar](100) NULL DEFAULT (''),
            	[ChildQty] [int] NULL DEFAULT ((0)),
            	[ParentSerialNo] [nvarchar](50) NULL DEFAULT (''),
            	[ParentSku] [nvarchar](20) NOT NULL DEFAULT (''),
            	[ParentItemID] [nvarchar](50) NULL DEFAULT (''),
            	[ParentProdLine] [nvarchar](50) NULL DEFAULT (''),
            	[VendorSerialNo] [nvarchar](50) NULL DEFAULT (''),
            	[VendorLotNo] [nvarchar](50) NULL DEFAULT (''),
            	[LotNo] [nvarchar](20) NULL DEFAULT (''),
            	[Revision] [nvarchar](10) NULL DEFAULT (''),
            	[CreationDate] [datetime] NULL,
            	[Source] [nvarchar](10) NULL DEFAULT (''),
            	[Status] [nvarchar](10) NULL DEFAULT ('0'),
            	[Attribute1] [nvarchar](50) NULL DEFAULT (''),
            	[Attribute2] [nvarchar](50) NULL DEFAULT (''),
            	[Attribute3] [nvarchar](50) NULL DEFAULT (''),
            	[RequestID] [int] NULL DEFAULT ((0)),
            	[UserDefine01] [nvarchar](30) NOT NULL DEFAULT (''),
            	[UserDefine02] [nvarchar](30) NOT NULL DEFAULT (''),
            	[UserDefine03] [nvarchar](30) NOT NULL DEFAULT (''),
            	[UserDefine04] [datetime] NULL,
            	[UserDefine05] [datetime] NULL,
            	[Addwho] [nvarchar](18) NULL  DEFAULT (suser_sname()),
            	[Adddate] [datetime] NULL  DEFAULT (getdate()),
            	[Editwho] [nvarchar](18) NULL  DEFAULT (suser_sname()),
            	[Editdate] [datetime] NULL  DEFAULT (getdate()),
            	[TrafficCop] [nchar](1) NULL,
            	[ArchiveCop] [nchar](1) NULL )  
            	         
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
   --@cLightMode  = LightMode,  
   @cSKU       = V_SKU,  
   --@cSKUDescr   = V_SKUDescr,  
   
   --@cLot        = V_Lot,  
   @cPUOM     = V_UOM,     
   
         
   @cWorkOrderNo        = V_String1,    
   @cOption             = V_String2,
   @n9LQty              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,  
   @nInnerQty           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,  
   @nMasterQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,  
   --@nTotalMasterQty     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,  
   @cGenSerialSP        = V_String6,
   @cBatchKey           = V_String7,
               
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
      
      
IF @nFunc = 1013  -- Serial No Kitting
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- Serial No Kitting
   IF @nStep = 1 GOTO Step_1   -- Scn = 4890. WorkOrderNo, Option
   IF @nStep = 2 GOTO Step_2   -- Scn = 4891. SKU, Qty 
   IF @nStep = 3 GOTO Step_3   -- Scn = 4892. SKU, Child SerialNo 
   IF @nStep = 4 GOTO Step_4   -- Scn = 4893. SKU, Parent SerialNo 
   IF @nStep = 5 GOTO Step_5   -- Scn = 4893. SKU, Parent SerialNo 
         
END      
      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 1010. Menu      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Get prefer UOM      
   SET @cPUOM = ''      
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA      
   FROM RDT.rdtMobRec M WITH (NOLOCK)      
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)      
   WHERE M.Mobile = @nMobile      
       
   
   SET @cGenSerialSP = ''  
   SET @cGenSerialSP = rdt.RDTGetConfig( @nFunc, 'GenSerialSP', @cStorerKey)  
   IF @cGenSerialSP = '0'    
   BEGIN  
      SET @cGenSerialSP = ''  
   END   

      
   -- Initiate var      
   -- EventLog - Sign In Function      
   EXEC RDT.rdt_STD_EventLog      
     @cActionType = '1', -- Sign in function      
     @cUserID     = @cUserName,      
     @nMobileNo   = @nMobile,      
     @nFunctionID = @nFunc,      
     @cFacility   = @cFacility,      
     @cStorerKey  = @cStorerkey      
           
   
   SET @cWorkOrderNo = ''
   SET @cOption      = ''

   -- Init screen      
   SET @cOutField01 = ''       
   SET @cOutField02 = ''      
      
   -- Set the entry point      
   SET @nScn = 4990      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Scn = 4990.      
   WorkOrderNo     (field01 , input)      
     
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cWorkOrderNo = ISNULL(RTRIM(@cInField01),'')      
      SET @cOption      = ISNULL(RTRIM(@cInField02),'')      
          
      IF @cWorkOrderNo = ''
      BEGIN
         SET @nErrNo = 113101      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WorkOrdeRNoReq    
         SET @cWorkOrderNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail  
      END
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND Facility = @cFacility  
                      AND WorkOrderKey = @cWorkOrderNo )   
      BEGIN  
         SET @nErrNo = 113102      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder
         SET @cWorkOrderNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail      
      END    
      
      IF ISNULL(@cOption,'' )  = '' 
      BEGIN
         SET @nErrNo = 113103      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         SET @cOption = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail      
      END
      
      IF @cOption NOT IN ('1','2' ) 
      BEGIN
         SET @nErrNo = 113104      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         SET @cOption = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail      
      END
      
      IF @cOption = '1' 
      BEGIN
         -- Prepare Next Screen Variable      
         --SET @cOutField01 = @cPTSZone    
         SET @cOutField01 = ''  
         SET @cOutField02 = ''
         
         -- GOTO Next Screen      
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1     
                
         
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
      ELSE IF @cOption = '2' 
      BEGIN
         SET @cSKU = ''
         SET @cChildSerialNo = ''
         
         -- Prepare Next Screen Variable      
         --SET @cOutField01 = @cPTSZone    
         SET @cOutField01 = ''  
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         
         -- GOTO Next Screen      
         SET @nScn = @nScn + 2      
         SET @nStep = @nStep + 2     
         
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
      EXEC RDT.rdt_STD_EventLog      
        @cActionType = '9', -- Sign in function      
        @cUserID     = @cUserName,      
        @nMobileNo   = @nMobile,      
        @nFunctionID = @nFunc,      
        @cFacility   = @cFacility,      
        @cStorerKey  = @cStorerkey      
              
      --go to main menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = ''      
  
   END      
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
      -- Prepare Next Screen Variable      
      SET @cOutField01 = @cWorkOrderNo
      SET @cOutField02 = @cOption
     
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 4991.       
       
   SKU        (field01, input)      
   Quantity   (field02, input)      
  
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cSKUInput    = ISNULL(RTRIM(@cInField01),'')      
      SET @nMasterQty   = ISNULL(RTRIM(@cInField02),'')   
      
      --SET @cSKUInput = '960-000370'
      --SET @nMasterQty = 2 
           
      IF @cSKUInput = ''      
      BEGIN      
         SET @nErrNo = 113105      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail    
      END      
      
      -- Get SKU barcode count    
      --DECLARE @nSKUCnt INT    
      EXEC rdt.rdt_GETSKUCNT    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      -- Check SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 113106    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU  
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail    
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 113107 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail    
      END    
      
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput     OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      IF @nErrNo = 0 
      BEGIN
         SET @cSKU = @cSKUInput
      END
      
      SELECT 
             
            @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')
      FROM dbo.WorkOrder WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo 
      
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'') 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo 
            
      
      IF @cSKU <> @cWorkOrderSKU
      BEGIN
         SET @nErrNo = 113110
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail  
      END
      
      
      --IF @nMasterQty = ''
      --BEGIN
      --   SET @nErrNo = 113108
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QtyReq'
      --   SET @nMasterQty = 0 
      --   EXEC rdt.rdtSetFocusField @nMobile, 2
      --   GOTO Step_2_Fail
      --END
      
      IF RDT.rdtIsValidQTY( @nMasterQty, 1) = 0
      BEGIN
         SET @nErrNo = 113109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         SET @nMasterQty = 0 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END
      
      -- Generating Label
      
      IF @cGenerateLabel = '1'
      BEGIN
         SELECT @cPrinter9L = UDF01 
               ,@cPrinterInner = UDF02 
               ,@cPrinterMaster = UDF03
               ,@cPrinterGTIN = UDF04
         FROM dbo.CodeLkup WITH (NOLOCK) 
         WHERE ListName = 'SERIALPRN'
         AND StorerKey = @cStorerKey
         AND Code = @cUserName 
         
         SELECT @cPackKey = PackKey
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU         = @cSKU
         
         SELECT @nInnerPack = ISNULL(InnerPack,0) 
               ,@nCaseCnt  = ISNULL(CaseCnt,0) 
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE PackKey = @cPackKey 
         
         SET @n9LQty     = 0 
         SET @nInnerQty  = 0 
         
         
         SET @n9LQty = @nMasterQty * @nCaseCnt
         
         IF @nInnerPack > 0 
         BEGIN
             SET @nInnerQty  = @nMasterQty * ( @nCaseCnt / @nInnerPack ) 
         END 
         
         
       
         -- Print 9L 
--         SET @nCount = 1 
--         WHILE @nCount <= @n9LQty
--         BEGIN
--           
--
--            SET @c9LSerialNo = ''
--            
--            IF @cGenSerialSP <> ''  
--            BEGIN  
--                 IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')  
--                 BEGIN  
--                       
--
--                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +  
--                                 ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'  
--                     SET @cSQLParam =  
--                        ' @nMobile                   INT,                     '+
--                        ' @nFunc                     INT,                     '+
--                        ' @cLangCode            NVARCHAR( 3),            '+
--                        ' @nStep                     INT,                     '+
--                        ' @nInputKey                 INT,                     '+
--                        ' @cStorerkey                NVARCHAR( 15),           '+
--                        ' @cFromSKU                  NVARCHAR( 20),           '+
--                        ' @cToSKU                    NVARCHAR( 20),           '+
--                        ' @cSerialNo                 NVARCHAR( 20),           '+
--                        ' @cSerialType               NVARCHAR( 10),           '+
--                        ' @cWorkOrderKey             NVARCHAR( 10),           '+
--                        ' @cBatchKey                 NVARCHAR( 10),           '+
--                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+
--                        ' @nErrNo                    INT           OUTPUT,    '+
--                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '
--                        
--                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
--                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'EACHES' ,@cWorkOrderNo ,@cBatchKey ,@c9LSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT
--              
--                     
--
--                     IF @nErrNo <> 0   
--                     BEGIN  
--                        SET @nErrNo = 113111    
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'    
--                        SET @cSerialNo = ''
--                        EXEC rdt.rdtSetFocusField @nMobile, 3   
--                        GOTO Step_2_Fail
--                     END  
--                 END  
--            END 
--            
--            SELECT @cDataWindow = DataWindow,     
--   	      		@cTargetDB = TargetDB     
--   			FROM rdt.rdtReport WITH (NOLOCK)     
--   			WHERE StorerKey = @cStorerKey    
--   			AND   ReportType = 'LOG9LLABEL'   
--   			
--   			-- Bartender No Datawindow Required (SHONG)
--   			--IF ISNULL(@cDataWindow,'')  <> ''  
--   			BEGIN
--      			EXEC RDT.rdt_BuiltPrintJob      
--      			             @nMobile,      
--      			             @cStorerKey,      
--      			             'LOG9LLABEL',  -- ReportType      
--      			             'Serial9L',    -- PrintJobName      
--      			             @cDataWindow,      
--      			             @cPrinter9L,      
--      			             @cTargetDB,      
--      			             @cLangCode,      
--      			             @nErrNo  OUTPUT,      
--      			             @cErrMsg OUTPUT, 
--      			             @c9LSerialNo 
--      			             
--   			END
--            
--            SET @nCount = @nCount + 1 
--         END
         
         
         

         -- Print Inner 
         IF @nInnerPack > 0 
         BEGIN
            SET @nCount = 1 
            WHILE @nCount <= @nInnerQty
            BEGIN
               SET @cInnerSerialNo = ''
               IF @cGenSerialSP <> ''  
               BEGIN  
                 
                 

                 IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')  
                 BEGIN  
                        
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +  
                     ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'  
                     SET @cSQLParam =  
                        ' @nMobile                   INT,                     '+
                        ' @nFunc                     INT,                     '+
                        ' @cLangCode                 NVARCHAR( 3),            '+
                        ' @nStep                     INT,                     '+
                        ' @nInputKey                 INT,                     '+
                      ' @cStorerkey                NVARCHAR( 15),           '+
                        ' @cFromSKU                  NVARCHAR( 20),           '+
                        ' @cToSKU                    NVARCHAR( 20),           '+
                        ' @cSerialNo                 NVARCHAR( 20),           '+
                        ' @cSerialType               NVARCHAR( 10),           '+
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+
                        ' @cBatchKey                 NVARCHAR( 10),           '+
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+
                        ' @nErrNo                    INT           OUTPUT,    '+
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '
                        
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'INNER' ,@cWorkOrderNo ,@cBatchKey ,@cInnerSerialNo OUTPUT,@nErrNo OUTPUT ,@cErrMsg OUTPUT
                 
                     

                     IF @nErrNo <> 0   
                     BEGIN  
                        SET @nErrNo = 113112    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'    
                        SET @cSerialNo = ''
                        EXEC rdt.rdtSetFocusField @nMobile, 3   
                        GOTO Step_2_Fail
                     END  

                     
                 END  
                 
               END 
               
               -- Print LabelNo 
               SELECT @cDataWindow = DataWindow,     
      	      		@cTargetDB = TargetDB     
      			FROM rdt.rdtReport WITH (NOLOCK)     
      			WHERE StorerKey = @cStorerKey    
      			AND   ReportType = 'LOGMASTLBL'   
      			
      			-- Bartender No Datawindow Required (SHONG)
      			--IF ISNULL(@cDataWindow,'')  <> '' 
      			BEGIN
         			EXEC RDT.rdt_BuiltPrintJob      
         			             @nMobile,      
         			             @cStorerKey,      
         			             'LOGMASTLBL',    -- ReportType      
         			             'SerialInnner',    -- PrintJobName      
         			             @cDataWindow,      
         			             @cPrinterInner,      
         			             @cTargetDB,      
         			             @cLangCode,      
         			             @nErrNo  OUTPUT,      
         			             @cErrMsg OUTPUT, 
         			             @cStorerKey,
      				             @cSKU,   
      				             @cWorkOrderNo,
      				             @nInnerPack,
      				             @cInnerSerialNo
      			END
               SET @nCount = @nCount + 1 
            END
         END
         
         -- Print Master Label
         SET @nCount = 1 
         WHILE @nCount <= @nMasterQty
         BEGIN
            SET @cMasterSerialNo = ''
            IF @cGenSerialSP <> ''  
            BEGIN  
                  
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenSerialSP AND type = 'P')  
                  BEGIN  
                       
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenSerialSP) +  
                     ' @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,@cSerialType ,@cWorkOrderKey ,@cBatchKey ,@cNewSerialNo OUTPUT ,@nErrNo OUTPUT ,@cErrMsg OUTPUT'  
                     SET @cSQLParam =  
                        ' @nMobile                   INT,                     '+
                        ' @nFunc                     INT,                     '+
                        ' @cLangCode                 NVARCHAR( 3),            '+
                        ' @nStep                     INT,                     '+
                        ' @nInputKey                 INT,     '+
                        ' @cStorerkey                NVARCHAR( 15),           '+
                        ' @cFromSKU                  NVARCHAR( 20),           '+
                        ' @cToSKU                    NVARCHAR( 20),           '+
                        ' @cSerialNo                 NVARCHAR( 20),           '+
                        ' @cSerialType               NVARCHAR( 10),           '+
                        ' @cWorkOrderKey             NVARCHAR( 10),           '+
                        ' @cBatchKey                 NVARCHAR( 10),           '+
                        ' @cNewSerialNo              NVARCHAR( 20) OUTPUT,    '+
                        ' @nErrNo                    INT           OUTPUT,    '+
                        ' @cErrMsg                   NVARCHAR( 20) OUTPUT     '
                        
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                        @nMobile ,@nFunc ,@cLangCode ,@nStep ,@nInputKey ,@cStorerkey ,@cFromSKU ,@cToSKU ,@cSerialNo ,'MASTER' ,@cWorkOrderNo ,@cBatchKey ,@cMasterSerialNo OUTPUT, @nErrNo OUTPUT ,@cErrMsg OUTPUT
              
                     

                     IF @nErrNo <> 0   
                     BEGIN  
                        SET @nErrNo = 113113    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenSerialNoFail'    
                        SET @cSerialNo = ''
                        EXEC rdt.rdtSetFocusField @nMobile, 3   
                        GOTO Step_2_Fail
                     END  
                 END  
            END 
            
            -- Print LabelNo 
            SELECT @cDataWindow = DataWindow,     
   	      		@cTargetDB = TargetDB     
   			FROM rdt.rdtReport WITH (NOLOCK)     
   			WHERE StorerKey = @cStorerKey    
   			AND   ReportType = 'LOGMASTLBL'   
   			
   			-- Bartender No Datawindow Required (SHONG) 
   			--IF ISNULL(@cDataWindow,'')  <> '' 
   			BEGIN
      			EXEC RDT.rdt_BuiltPrintJob      
      			             @nMobile,      
      			             @cStorerKey,      
      			             'LOGMASTLBL',    -- ReportType      
      			             'SerialMaster',    -- PrintJobName      
      			             @cDataWindow,      
      			             @cPrinterMaster,      
      			             @cTargetDB,      
      			             @cLangCode,      
      			             @nErrNo  OUTPUT,      
      			             @cErrMsg OUTPUT, 
      			             @cStorerKey,
   				             @cSKU,   
   				             @cWorkOrderNo,
   				             @nCaseCnt,
   				             @cMasterSerialNo
   			END
            
            SET @nCount = @nCount + 1 
         END
      END
            
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1  
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      
      SET @cOutField01 = @cSKU   
      SET @cOutField02 = @nMasterQty   
      
            
   END      
      
END       
GOTO QUIT      
      
/********************************************************************************      
Step 3. Scn = 4992.       
       
   SKU            (field01, input)      
   Child SerialNo (field02, input)      
  
         
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cSKUInput        = ISNULL(RTRIM(@cInField01),'')      
      SET @cChildSerialNo   = ISNULL(RTRIM(@cInField02),'')   
      
      --SET @cSKUInput = '001172-0000'
      --SET @cChildSerialNo = '1725FSAP2859' 

      
--      1725FSAP2879   1729FSAP291C   1729FSAP293M
--      1725FSAP2869   
--      1725FSAP2859   1729FSAP290C
--      1725FSAP2849
--      1725FSAP2839   1729FSAP289C   1729FSAP292M
--      1725FSAP2829   
--      1725FSAP2819   1729FSAP288C
--      1725FSAP2809
           
      IF @cSKUInput = ''      
      BEGIN      
         SET @nErrNo = 113114      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKUReq'
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_3_Fail    
      END      
      
      -- Get SKU barcode count    
      --DECLARE @nSKUCnt INT    
      EXEC rdt.rdt_GETSKUCNT    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      -- Check SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 113115    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU  
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail    
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 113116 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_3_Fail    
      END    
      
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cSKUInput     OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      IF @nErrNo = 0 
      BEGIN
         SET @cSKU = @cSKUInput
      END
      
      SELECT 
             @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')
      FROM dbo.WorkOrder WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo 
      
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'') 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo 
      
      SELECT 
             @nMasterQty     = ISNULL(Qty,0 ) 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE StorerKey  = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo
      AND Unit         = 'Master'
         
      
      IF @cSKU <> @cWorkOrderSKU
      BEGIN
         SET @nErrNo = 113117
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU    
         SET @cSKU = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_3_Fail  
      END
      
      SET @cPackKey = ''
      SELECT @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU         = @cSKU
      
      SELECT @nInnerPack = ISNULL(InnerPack,0) 
            ,@nCaseCnt  = ISNULL(CaseCnt,0) 
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PackKey = @cPackKey 
      
      SET @n9LQty     = 0 
      SET @nInnerQty  = 0    
      SET @cPassed    = ''   
      
      --SET @n9LQty = @nMasterQty * @nCaseCnt
      
      IF @nInnerPack > 0 
      BEGIN
          SET @nInnerQty  = @nInnerPack -- @nMasterQty * ( @nCaseCnt / @nInnerPack ) 
      END 
      
      IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND Status <> '9' 
                  AND FromSKU = @cSKU
                  AND SourceKey = @cWorkOrderNo
                  AND Func = @nFunc 
                  AND AddWho = @cUserName ) 
      BEGIN
         SELECT TOP 1 @cBatchKey = BatchKey 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Status <> '9' 
         AND FromSKU = @cSKU
         AND SourceKey = @cWorkOrderNo
         AND Func = @nFunc 
         AND AddWho = @cUserName 
      END       
      ELSE
      BEGIN
         
         --GetKey 
         EXECUTE dbo.nspg_GetKey
                  'rdtSerial',
                  10 ,
                  @cBatchKey         OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
                  
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 113118
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetKeyFail
            GOTO Step_3_Fail
         END
         
      END   
      
      IF ISNULL(@cChildSerialNo,'')  <> '' 
      BEGIN 
         SET @cSerialType = RIGHT ( @cChildSerialNo , 1 ) 
      
         IF @cSerialType NOT IN ( '9' ) 
         BEGIN
            SET @nErrNo = 113120
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType
            SET @cChildSerialNo = '' 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_3_Fail
         END
      END
--      IF @nInnerQty = 0 AND @cSerialType = 'C'
--      BEGIN
--         SET @nErrNo = 113124
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType
--         GOTO Step_3_Fail
--      END
            
      IF @cSerialType = '9'
      BEGIN 
         IF NOT EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK) 
                         WHERE SKU = @cSKU
                         AND SerialNo = @cChildSerialNo
                         AND StorerKey = @cStorerKey  ) 
         BEGIN
            SET @nErrNo = 113125    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo    
            SET @cChildSerialNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 
            GOTO Step_3_Fail    
         END
         
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND Status <> '9' 
                     AND Func = @nFunc 
                     AND FromSerialNo = @cChildSerialNo )  
         BEGIN
            SET @nErrNo = 113126    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned    
            SET @cChildSerialNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 
            GOTO Step_3_Fail    
         END
         
         INSERT INTO rdt.rdtSerialNoLog ( StorerKey, Status, FromSerialNo, ToSerialNo, ParentSerialNo, FromSKU, ToSKU, SourceKey, SourceType, BatchKey, Remarks, Func, AddWho  ) 
         VALUES ( @cStorerKey, '1' , @cChildSerialNo, @cChildSerialNo, '', @cSKU, @cSKU,  @cWorkOrderNo, '', @cBatchKey, '' , @nFunc, @cUserName ) 
         
         IF @@ERROR <> 0 
         BEGIN
               SET @nErrNo = 113119
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsrdtSerailFail
               SET @cChildSerialNo = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2 
               GOTO Step_3_Fail
         END   

         SELECT @nScanCount = COUNT ( RowRef ) 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND FromSKU     = @cSKU
         AND BatchKey    = @cBatchKey
         AND SourceKey   = @cWorkOrderNo
         AND Func        = @nFunc 
         AND AddWho      = @cUserName 
         AND Status      = '1'
         
         
         IF @nInnerQty > 0 
         BEGIN
            IF @nInnerQty = @nScanCount
            BEGIN
               SET @cPassed = '1'
            END
         END
         ELSE 
         BEGIN
            IF @nCaseCnt = @nScanCount
            BEGIN
               SET @cPassed = '1'
            END
         END
         
         

         IF @cPassed = '1' 
         BEGIN
            
            IF @nInnerQty > 0 
            BEGIN
               
               -- Prepare Previous Screen Variable      
               SET @cOutField01 = @cSKU  
               SET @cOutField02 = ''
                        
               -- GOTO Previous Screen      
               SET @nScn = @nScn + 1      
               SET @nStep = @nStep + 1      
               
               GOTO QUIT 
               
            END
            ELSE
            BEGIN
               UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK) 
                  SET Status         ='5'
               WHERE @cBatchKey = @cBatchKey 
               AND Status = '1' 
               
               IF @@ERROR <> 0 
               BEGIN
                     SET @nErrNo = 113129
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail
                     SET @cChildSerialNo = ''
                     EXEC rdt.rdtSetFocusField @nMobile, 2 
                     GOTO Step_3_Fail
               END
               
               -- Prepare Previous Screen Variable      
               SET @cOutField01 = @cSKU  
               SET @cOutField02 = ''
                        
               -- GOTO Previous Screen      
               SET @nScn = @nScn + 2      
               SET @nStep = @nStep + 2      
               
               GOTO QUIT 
            END
            
         END
      END
     
      
      SET @cOutField01 =  @cSKU
      SET @cOutField02 =  ''
      
      IF @nInnerQty > 0 
      BEGIN
         SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nInnerPack AS NVARCHAR(5)) END
      END
      ELSE 
      BEGIN
         SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nCaseCnt AS NVARCHAR(5)) END
      END
      
      EXEC rdt.rdtSetFocusField @nMobile, 2 
            
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
       SET @cOutField02 = ''   
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 2      
       SET @nStep = @nStep - 2      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1  
   END      
   GOTO Quit      
         
   Step_3_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      
      SET @cOutField01 = @cSKU   
      SET @cOutField02 = ''   
      
      
            
   END      
      
END       
GOTO QUIT   

/********************************************************************************      
Step 4. Scn = 4993.       
       
   SKU             (field01)      
   Parent SerialNo (field02, input)      
  
         
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cChildSerialNo = '' 
      
      SET @cChildSerialNo   = ISNULL(RTRIM(@cInField02),'')   

      
      
      --SET @cSKUInput = '001172-0000'
      --SET @cChildSerialNo = '1729FSAP290C' 

      
--      1725FSAP2879   1729FSAP291C   1729FSAP293M
--      1725FSAP2869   
--      1725FSAP2859   1729FSAP290C
--      1725FSAP2849
--      1725FSAP2839   1729FSAP289C   1729FSAP292M
--      1725FSAP2829   
--      1725FSAP2819   1729FSAP288C
--      1725FSAP2809
           
      
      SELECT 
             @cWorkOrderSKU  = ISNULL(WKORDUDef3 ,'')
      FROM dbo.WorkOrder WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo 
      
      SELECT TOP 1 @cGenerateLabel = ISNULL(WKORDUDef1,'') 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderNo 
      
      SELECT 
             @nMasterQty     = ISNULL(Qty,0 ) 
      FROM dbo.WorkOrderDetail WITH (NOLOCK) 
      WHERE StorerKey  = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo
      AND Unit         = 'Master'
         
            
      SET @cPackKey = ''
      SELECT @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU         = @cSKU

    
      
      SELECT @nInnerPack = ISNULL(InnerPack,0) 
            ,@nCaseCnt  = ISNULL(CaseCnt,0) 
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PackKey = @cPackKey 
      
      SET @n9LQty     = 0 
      SET @nInnerQty  = 0    
      SET @cPassed    = ''   
      
      --SET @n9LQty = @nMasterQty * @nCaseCnt
      
      IF @nInnerPack > 0 
      BEGIN
          SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack ) 
      END 
      
 

      SET @cSerialType = RIGHT ( @cChildSerialNo , 1 ) 
      
      IF @cSerialType <> 'C'
      BEGIN
         SET @nErrNo = 113136
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType
         GOTO Step_4_Fail
      END
      
      IF @nInnerQty = 0 AND @cSerialType = 'C'
      BEGIN
         SET @nErrNo = 113124
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType
         GOTO Step_4_Fail
      END
           
         
      IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK) 
                      WHERE SKU = @cSKU
                      AND SerialNo = @cChildSerialNo
                      AND StorerKey = @cStorerKey  ) 
      BEGIN
         SET @nErrNo = 113127    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo    
         SET @cSerialNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         GOTO Step_4_Fail    
      END
            
      
      IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND Status <> '9' 
                  AND Func = @nFunc 
                  AND ParentSerialNo = @cChildSerialNo )  
      BEGIN
         SET @nErrNo = 113128    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned    
         SET @cSerialNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         GOTO Step_4_Fail    
      END
         
      UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK) 
         SET  ParentSerialNo = @cChildSerialNo
             ,Status         ='5'
      WHERE @cBatchKey = @cBatchKey 
      AND Status = '1' 
      
      IF @@ERROR <> 0 
      BEGIN
            SET @nErrNo = 113123
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail
            GOTO Step_4_Fail
      END
      
      
      SELECT @nScanCount = COUNT ( RowRef ) 
      FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND FromSKU     = @cSKU
      AND BatchKey    = @cBatchKey
      AND SourceKey   = @cWorkOrderNo
      AND Func        = @nFunc 
      AND AddWho      = @cUserName 
      AND Status      = '5'
      
      IF @nCaseCnt  = @nScanCount
      BEGIN
         
         -- Prepare Previous Screen Variable      
         SET @cOutField01 = @cSKU
         SET @cOutField02 = ''   
                   
         -- GOTO Previous Screen      
         SET @nScn = @nScn + 1 
         SET @nStep = @nStep + 1   
         
         GOTO QUIT 
         
      END
      ELSE
      BEGIN
         IF @nInnerQty > 0 
         BEGIN
            SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nInnerPack AS NVARCHAR(5)) END
         END
         ELSE 
         BEGIN
            SET @cOutField03 =  CASE WHEN @cSerialType = '9' THEN CAST(@nScanCount AS NVARCHAR(5))  + '/' + CAST(@nCaseCnt AS NVARCHAR(5)) END
         END
         
         -- Prepare Previous Screen Variable      
         SET @cOutField01 = @cSKU
         SET @cOutField02 = ''   
         
                   
         -- GOTO Previous Screen      
         SET @nScn = @nScn - 1 
         SET @nStep = @nStep - 1    
         
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         
         GOTO QUIT 
      END
         
      
      
     
      
            
            
   END  -- Inputkey = 1      
         
   --IF @nInputKey = 0       
   --BEGIN      
   --    -- Prepare Previous Screen Variable      
   --    SET @cOutField01 = ''   
   --    SET @cOutField02 = ''   
                
   --    -- GOTO Previous Screen      
   --    SET @nScn = @nScn - 2      
   --    SET @nStep = @nStep - 2      
             
   --    EXEC rdt.rdtSetFocusField @nMobile, 1  
   --END      
   GOTO Quit      
         
   Step_4_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      
      SET @cOutField01 = @cSKU   
      SET @cOutField02 = ''   
      
      
            
   END      
      
END       
GOTO QUIT


 
/********************************************************************************      
Step 5. Scn = 4994.       
       
   SKU             (field01)      
   Master SerialNo (field02, input)      
  
         
********************************************************************************/      
Step_5:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      
      SET @cMasterSerialNo   = ISNULL(RTRIM(@cInField02),'')   
      
      --SET @cMasterSerialNo = '1730FSAP824M'
      
      
--      1725FSAP2879   1729FSAP291C   1729FSAP293M
--      1725FSAP2869   
--      1725FSAP2859   1729FSAP290C
--      1725FSAP2849
--      1725FSAP2839   1729FSAP289C   1729FSAP292M
--      1725FSAP2829   
--      1725FSAP2819   1729FSAP288C
--      1725FSAP2809
     
      IF @cMasterSerialNo = ''      
      BEGIN      
         SET @nErrNo = 113130      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ParentSerialReq'
         GOTO Step_5_Fail    
      END      
      
      SET @cSerialType = RIGHT ( @cMasterSerialNo , 1 ) 
      
      IF @cSerialType <> 'M'
      BEGIN
         SET @nErrNo = 113137
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialType
         GOTO Step_5_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK) 
                         WHERE SKU = @cSKU
                         AND ParentSerialNo = @cMasterSerialNo  ) 
      BEGIN
         SET @nErrNo = 113131    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvSerialNo    
         GOTO Step_5_Fail    
      END
      
      IF EXISTS ( SELECT 1 FROM rdt.rdtserialNoLog WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND Status <> '9' 
                  AND Func = @nFunc 
                  AND Remarks = @cMasterSerialNo )  
      BEGIN
         SET @nErrNo = 113132    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoScanned    
         GOTO Step_5_Fail    
      END
      
      SELECT @cLocationCode = SHORT 
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE LISTNAME = 'LOGILOC' 
      AND CODE = @cFacility

      SET @cPackKey = ''
      SELECT @cPackKey = PackKey
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU         = @cSKU
      
      SELECT @nInnerPack = ISNULL(InnerPack,0) 
            ,@nCaseCnt  = ISNULL(CaseCnt,0) 
      FROM dbo.Pack WITH (NOLOCK) 
      WHERE PackKey = @cPackKey 
      
      
      SET @n9LQty     = 0 
      SET @nInnerQty  = 0    
      SET @cPassed    = ''   
      
      --SET @n9LQty = @nMasterQty * @nCaseCnt
      SET @nCLabelQty = 0 
      
      IF @nInnerPack > 0 
      BEGIN
          SET @nInnerQty  = @nInnerPack --@nMasterQty * ( @nCaseCnt / @nInnerPack ) 
      
          SET @nCLabelQty = @nCaseCnt / @nInnerQty
      END 
      ELSE
      BEGIN
         SET @nCLabelQty = @nCaseCnt 
      END
      
      

      -- Create Master Records -- 
      DECLARE CUR_SERIALSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
       
      SELECT RowRef, ToSerialNo, ParentSerialNo, Remarks
      FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND Status = '5' 
      AND ToSKU = @cSKU
      AND SourceKey = @cWorkOrderNo
      AND Func = @nFunc 
      AND AddWho = @cUserName
      AND BatchKey = @cBatchKey
      ORDER By ParentSerialNo 
      
      OPEN CUR_SERIALSKU
      FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         
         --PRINT  @cToSerialNo
         IF ISNULL(@cParentSerialNo,'')  = '' 
         BEGIN 
               SET @cParentSerialNo = @cMasterserialNo
         END

         -- Delete And Insert 9L Records -- 
         
         -- Insert into Temp Table before Delete
         INSERT INTO @tMasterSerialTemp (
                      LocationCode 	      ,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
               	   ,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
               	   ,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
               	   ,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
               	   ,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
         SELECT TOP 1 LocationCode   	,UnitType 	      ,PartnerType 	,SerialNo 	   ,ElectronicSN 	   ,Storerkey	
               ,SKU              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo   ,ParentSKU 	   ,ParentItemID 	  
               ,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	         ,CreationDate	,Source 	      
               ,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	         ,UserDefine01 	,UserDefine02 	
               ,@cBatchKey 	      ,UserDefine04 	   ,UserDefine05 	
         FROM dbo.MASTERSERIALNO WITH (NOLOCK) 
         WHERE SerialNo = @cToSerialNo
         
         -- Delete MasterSerialNo Records 
         DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK) 
         WHERE SerialNo = @cToSerialNo
         
         IF @@ERROR <> 0 
         BEGIN
           SET @nErrNo = 113137
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerialFail
           GOTO Step_5_Fail 
         END

         -- Insert New 9L Serial No Records
         INSERT INTO MASTERSERIALNO (
                   	 LocationCode 	      ,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
                   	,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
                   	,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
                   	,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
                   	,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
         SELECT TOP 1 @cLocationCode   	,RIGHT(@cToSerialNo,1) 	      ,PartnerType 	,@cToSerialNo   	,ElectronicSN 	      ,Storerkey	
                ,@cSKU              	,ItemID 	         ,ItemDescr 	   ,CASE WHEN @nInnerPack > 0 THEN @nInnerPack ELSE @nCaseCnt END	    	   ,@cParentSerialNo	   ,@cSKU 	      ,ParentItemID 	  
                ,ParentProdLine	      ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	         ,CreationDate	,@cWorkOrderNo 	      
                ,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	         ,UserDefine01 	,UserDefine02 	
                ,@cBatchKey 	      ,UserDefine04 	   ,UserDefine05 	
         FROM @tMasterSerialTemp 
         WHERE SerialNo = @cToSerialNo
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 113133
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail
            GOTO Step_5_Fail
         END

                           
         SELECT @cOriginalParentSerialNo = ParentSerialNo
         FROM dbo.MasterSerialNo WITH (NOLOCK) 
         WHERE SerialNo = @cFromSerialNo
         
         
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND SerialNo = @cOriginalParentSerialNo ) 
         BEGIN 
            DELETE FROM dbo.MasterSerialNo WITH (ROWLOCK) 
            WHERE StorerKey = @cStorerKey
            AND SerialNo = @cOriginalParentSerialNo

            IF @@ERROR <> 0 
            BEGIN
              SET @nErrNo = 113138
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelMasterSerailFail
              GOTO Step_5_Fail
            END
         END
                  

         IF ISNULL(@nInnerQty,0 ) > 0 
         BEGIN 
            

            IF NOT EXISTS (SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey 
                           AND SKU = @cSKU
                           AND SerialNo =  @cParentSerialNo) 
            BEGIN
               

               -- Insert New Inner Serial No Records
               INSERT INTO MASTERSERIALNO (
                         	LocationCode 	      ,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
                         	,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
                         	,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
                         	,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
                         	,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
               SELECT TOP 1 @cLocationCode 	,RIGHT(@cParentSerialNo,1) 	      ,PartnerType 	,@cParentSerialNo    ,ElectronicSN 	   ,Storerkey	
                      ,@cSKU             	,ItemID 	         ,ItemDescr 	   ,@nCLabelQty       ,@cMasterserialNo    ,@cSKU 	   ,ParentItemID 	  
                      ,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	         ,CreationDate	,@cWorkOrderNo 	      
                      ,Status 	         ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	         ,UserDefine01 	,UserDefine02 	
                      ,@cBatchKey 	   ,UserDefine04 	   ,UserDefine05 	
               FROM dbo.MASTERSERIALNO WITH (NOLOCK) 
               WHERE SerialNo = @cToSerialNo
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 113134
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsMasterSerialFail
                  GOTO Step_5_Fail
               END
               
            END
         END
         
         UPDATE rdt.rdtSerialNoLog WITH (ROWLOCK) 
         SET Status = '9'
            ,Remarks = @cMasterserialNo 
         WHERE StorerKey = @cStorerKey
         AND Status = '5' 
         AND SourceKey = @cWorkOrderNo
         AND Func = @nFunc 
         AND BatchKey = @cBatchKey
         AND AddWho = @cUserName
         AND RowRef = @nRowRef
         
         IF @@ERROR <>  0 
         BEGIN
             SET @nErrNo = 113135
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdrdtSerailFail
             GOTO Step_5_Fail
         END                   
         
         FETCH NEXT FROM CUR_SERIALSKU INTO @nRowRef, @cToSerialNo, @cParentSerialNo, @cRemarks
         
      END
      CLOSE CUR_SERIALSKU      
      DEALLOCATE CUR_SERIALSKU
      
      
      SET @cOutField01 = ''   
      SET @cOutField02 = ''   
      SET @cOutField03 = ''  
                
      -- GOTO Previous Screen      
      SET @nScn = @nScn - 2      
      SET @nStep = @nStep - 2    
      
      EXEC rdt.rdtSetFocusField @nMobile, 1        
            
   END  -- Inputkey = 1      
         
--   IF @nInputKey = 0       
--   BEGIN      
--       -- Prepare Previous Screen Variable      
--       SET @cOutField01 = ''   
--       SET @cOutField02 = ''   
--                
--       -- GOTO Previous Screen      
--       SET @nScn = @nScn - 1      
--       SET @nStep = @nStep - 1      
--             
--       EXEC rdt.rdtSetFocusField @nMobile, 1  
--   END      
   GOTO Quit      
         
   Step_5_Fail:      
   BEGIN      
      
      -- Prepare Next Screen Variable      
      
      SET @cOutField01 = @cSKU   
      SET @cOutField02 = ''   
      
      
            
   END      
      
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
      --UserName  = @cUserName,     
      EditDate  = GetDate() ,  
      InputKey  = @nInputKey,   
     --LightMode = @cLightMode,  
            
      --V_SKUDescr = @cSKUDescr,  
      --V_UOM = @cPUOM,  
      V_SKU = @cSKU,   
      --V_Qty = @nExpectedQTY,  
      --V_Lot = @cLot,
    
      V_String1 = @cWorkOrderNo  ,    
      V_String2 = @cOption       ,    
      V_String3 = @n9LQty        ,    
      V_String4 = @nInnerQty     ,    
      V_String5 = @nMasterQty    ,    
      --V_String6 = @nTotalMasterQty,
      V_String6 = @cGenSerialSP,
      V_String7 = @cBatchKey,

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
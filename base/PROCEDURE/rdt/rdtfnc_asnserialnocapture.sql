SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/******************************************************************************/                 
/* Copyright: LF                                                              */                 
/* Purpose: SeialNo Capture                                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-03-31 1.0  YeeKung    WMS-12575 Created                               */  
/* 2021-10-14 1.1  YeeKung    WMS-18116 add format serialno (yeekung01)       */              
/******************************************************************************/                
                
CREATE PROC [RDT].[rdtfnc_ASNSerialNoCapture] (                
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
   @nCount              INT,                  
   @nRowCount           INT,
   @cSQL                NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( MAX)              
            
-- RDT.RDTMobRec variable                  
DECLARE                   
   @nFunc               INT,                  
   @nScn                INT,                  
   @nStep               INT,                  
   @cLangCode           NVARCHAR( 3),                  
   @nInputKey           INT,                  
   @nMenu               INT,                  
                  
   @cStorerKey          NVARCHAR( 15),                  
   @cFacility           NVARCHAR( 5),                   
   @cPrinter            NVARCHAR( 20),                   
   @cUserName           NVARCHAR( 18),                  
                     
   @nError              INT,                  
   @b_success           INT,                  
   @n_err               INT,                       
   @c_errmsg            NVARCHAR( 250),                   
   @cPUOM               NVARCHAR( 10),                      
   @bSuccess            INT,    
   
   @cReceiptKey         NVARCHAR ( 20), 
   @cChkFacility        NVARCHAR ( 20),  
   @cChkStorerKey       NVARCHAR ( 20),
   @cSKU                NVARCHAR ( 20), 
   @cMultiSKUBarcode    NVARCHAR(1), 
   @cExtendedValidateSP NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),

   @nFromScn            INT,      
   @cID                 NVARCHAR( 20),
   @cBatchCode          NVARCHAR( 20), 
   @cCartonSN           NVARCHAR( 60),
   @cBottleSN           NVARCHAR( 100),
   @nQTYPICKED          INT,
   @nQTYCSN             INT,
   @cMax                NVARCHAR( MAX),
   @cDefaultBatchNo     NVARCHAR(1),
                  
   @cInField01 NVARCHAR( 60),    @cOutField01 NVARCHAR( 60),                  
   @cInField02 NVARCHAR( 60),    @cOutField02 NVARCHAR( 60),                  
   @cInField03 NVARCHAR( 60),    @cOutField03 NVARCHAR( 60),                  
   @cInField04 NVARCHAR( 60),    @cOutField04 NVARCHAR( 60),                  
   @cInField05 NVARCHAR( 60),    @cOutField05 NVARCHAR( 60),                  
   @cInField06 NVARCHAR( 60),    @cOutField06 NVARCHAR( 60),                   
   @cInField07 NVARCHAR( 60),    @cOutField07 NVARCHAR( 60),                   
   @cInField08 NVARCHAR( 60),    @cOutField08 NVARCHAR( 60),                   
   @cInField09 NVARCHAR( 60),    @cOutField09 NVARCHAR( 60),                   
   @cInField10 NVARCHAR( 60),    @cOutField10 NVARCHAR( 60),                   
   @cInField11 NVARCHAR( 60),    @cOutField11 NVARCHAR( 60),                   
   @cInField12 NVARCHAR( 60),    @cOutField12 NVARCHAR( 60),                   
   @cInField13 NVARCHAR( 60),    @cOutField13 NVARCHAR( 60),                   
   @cInField14 NVARCHAR( 60),    @cOutField14 NVARCHAR( 60),                   
   @cInField15 NVARCHAR( 60),    @cOutField15 NVARCHAR( 60),                  
                  
   @cFieldAttr01 NVARCHAR( 1),   @cFieldAttr02 NVARCHAR( 1),                  
   @cFieldAttr03 NVARCHAR( 1),   @cFieldAttr04 NVARCHAR( 1),                  
   @cFieldAttr05 NVARCHAR( 1),   @cFieldAttr06 NVARCHAR( 1),                  
   @cFieldAttr07 NVARCHAR( 1),   @cFieldAttr08 NVARCHAR( 1),                  
   @cFieldAttr09 NVARCHAR( 1),   @cFieldAttr10 NVARCHAR( 1),                  
   @cFieldAttr11 NVARCHAR( 1),   @cFieldAttr12 NVARCHAR( 1),                  
   @cFieldAttr13 NVARCHAR( 1),   @cFieldAttr14 NVARCHAR( 1),                  
   @cFieldAttr15 NVARCHAR( 1)                  
                     
-- Load RDT.RDTMobRec                  
SELECT                   
   @nFunc               = Func,                  
   @nScn                = Scn,                  
   @nStep               = Step,                  
   @nInputKey           = InputKey,                  
   @nMenu               = Menu,                  
   @cLangCode           = Lang_code,                  
                  
   @cStorerKey          = StorerKey,                  
   @cFacility           = Facility,                  
   @cPrinter            = Printer,                   
   @cUserName           = UserName,                              
                   
   @cPUOM               = V_UOM,
   @cMax                = V_MAX, 
   
   @cReceiptKey         = V_String1,
   @cChkFacility        = V_String2,
   @cChkStorerKey       = V_String3,
   @cMultiSKUBarcode    = V_String4,
   @cExtendedValidateSP = V_String5,
   @cExtendedUpdateSP   = V_String6,
   @cID                 = V_String7,
   @cBatchCode          = V_string8,
   @cCartonSN           = V_string9,
   @cSKU                = V_string10,
   @cDefaultBatchNo     = V_string11,

   @nFromScn             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 5), 0) = 1 THEN LEFT( V_String20, 5) ELSE 0 END,
                 
   @nQTYPICKED          = V_Integer1,
   @nQTYCSN             = V_Integer2,

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
                  
   @cFieldAttr01  =  FieldAttr01,    @cFieldAttr02    = FieldAttr02,                  
   @cFieldAttr03  =  FieldAttr03,    @cFieldAttr04    = FieldAttr04,                  
   @cFieldAttr05  =  FieldAttr05,    @cFieldAttr06    = FieldAttr06,                  
   @cFieldAttr07  =  FieldAttr07,    @cFieldAttr08    = FieldAttr08,                  
   @cFieldAttr09  =  FieldAttr09,    @cFieldAttr10    = FieldAttr10,                  
   @cFieldAttr11  =  FieldAttr11,    @cFieldAttr12    = FieldAttr12,                  
   @cFieldAttr13  =  FieldAttr13,    @cFieldAttr14    = FieldAttr14,                  
   @cFieldAttr15  =  FieldAttr15                  
                  
FROM RDTMOBREC (NOLOCK)                  
WHERE Mobile = @nMobile                  
                  
Declare @n_debug INT                  
                  
SET @n_debug = 0               
            
IF @nFunc = 645  -- Serial No Capture                  
BEGIN                  
                     
   -- Redirect to respective screen                  
   IF @nStep = 0 GOTO Step_0   -- PTL DropID Cont                  
   IF @nStep = 1 GOTO Step_1   -- Scn = 5730. ASN              
   IF @nStep = 2 GOTO Step_2   -- Scn = 5731. SKU               
   IF @nStep = 3 GOTO Step_3   -- Scn = 5732. PalletID                 
   IF @nStep = 4 GOTO Step_4   -- Scn = 5733. BatchCode             
   IF @nStep = 5 GOTO Step_5   -- Scn = 5734. Carton SN        
   IF @nStep = 6 GOTO Step_6   -- Scn = 5735. Bottle SN       
   IF @nStep = 7 GOTO Step_7   -- Scn = 3570. Multi SKU Barocde                 
                     
END                  
                    
RETURN -- Do nothing if incorrect step       
    
/********************************************************************************                  
Step 0. func = 1835. Menu                  
********************************************************************************/                  
Step_0:                  
BEGIN                                
                   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)                
   IF @cExtendedUpdateSP = '0'                  
   BEGIN                
      SET @cExtendedUpdateSP = ''                
   END
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''                  
   
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)   
   
   SET @cDefaultBatchNo = rdt.RDTGetConfig( @nFunc, 'DefaultBatchNo', @cStorerKey)                    
              
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
   SET @cOutField02 = ''                                         
                          
   -- Set the entry point                  
   SET @nScn = 5730                  
   SET @nStep = 1                  
                     
   EXEC rdt.rdtSetFocusField @nMobile, 1                  
                     
END            
GOTO Quit                 
         
/********************************************************************************                  
Step 1. Scn = 5730.                     
   ASN         (field01, input)            
********************************************************************************/             
Step_1:                  
BEGIN         
   IF @nInputKey = 1
   BEGIN 
      SET @cReceiptKey = @cInField01  

      IF ISNULL(@cReceiptKey, '') =''
      BEGIN
         SET @nErrNo = 150501   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Receiptkeyneed  
         GOTO step_1_fail
      END

      SELECT  
         @cChkFacility = R.Facility,  
         @cChkStorerKey = R.StorerKey 
      FROM dbo.Receipt R WITH (NOLOCK)  
      WHERE R.ReceiptKey = @cReceiptKey  
      SET @nRowCount = @@ROWCOUNT  

      IF (@nRowCount = 0)
      BEGIN
         SET @nErrNo = 150502   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvRECKEY 
         GOTO step_1_fail
      END

      IF (@cChkFacility<>@cFacility)
      BEGIN
         SET @nErrNo = 150503   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffFacility  
         GOTO step_1_fail
      END

      IF (@cChkStorerKey<>@cStorerkey)
      BEGIN
         SET @nErrNo = 150504   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --
         GOTO step_1_fail
      END

      -- Prepare next screen var  
      SET @cOutField01 = @cReceiptKey  
  
      -- Go to next screen  
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
  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  

   
   Step_1_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cOutField01 = '' -- ReceiptKey  
      SET @cReceiptKey = ''   
   END
          
END       
GOTO Quit    

/********************************************************************************                  
Step 2. Scn = 5731.                     
   ASN         (field01, output) 
   SKU         (field02, input)    
********************************************************************************/             
Step_2:                  
BEGIN         
   IF @nInputKey = 1
   BEGIN 
      SET @cSKU = @cInField02  

      IF ISNULL(@cSKU, '') =''
      BEGIN
         SET @nErrNo = 150505   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Receiptkeyneed  
         GOTO step_2_fail
      END

      -- Get SKU  
      DECLARE @nSKUCnt INT 
      SET @nSKUCnt = 0  

      EXEC RDT.rdt_GetSKUCNT          
      @cStorerKey  = @cStorerKey          
      ,@cSKU        = @cSKU          
      ,@nSKUCnt     = @nSKUCnt   OUTPUT          
      ,@bSuccess    = @bSuccess  OUTPUT          
      ,@nErr        = @nErrNo    OUTPUT          
      ,@cErrMsg     = @cErrMsg   OUTPUT  
      ,@cSKUStatus  = 'ACTIVE'

      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 150506  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
         GOTO Step_2_Fail  
      END

      IF @nSKUCnt = 1  
      BEGIN  
         EXEC [RDT].[rdt_GETSKU]  
         @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU          OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @nErrNo        OUTPUT  
         ,@cErrMsg     = @cErrMsg       OUTPUT 

         SET @cSKU = @cSKU
      END 

        -- Check barcode return multi SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         -- (james03)  
         IF @cMultiSKUBarcode IN ('1', '2')  
         BEGIN  
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,  
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  
               'POPULATE',  
               @cMultiSKUBarcode,  
               @cStorerKey,  
               @cSKU     OUTPUT,  
               @nErrNo   OUTPUT,  
               @cErrMsg  OUTPUT,  
               'ASN',    -- DocType  
               @cReceiptKey  
  
            IF @nErrNo = 0 -- Populate multi SKU screen  
            BEGIN  
               -- Go to Multi SKU screen  
               SET @nFromScn = @nScn  
               SET @nScn = 3570  
               SET @nStep = @nStep + 5  
               GOTO Quit  
            END  
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen  
            BEGIN  
               SET @nErrNo = 0  
               SET @cSKU = @cSKU  
            END
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 150508  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod  
            GOTO Step_2_Fail  
         END  
  
      END  

      IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) 
                     WHERE SKU=@cSKU
                        AND Receiptkey=@cReceiptKey
                        AND Storerkey= @cStorerKey
                     )
      BEGIN
         SET @nErrNo = 150507   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNOTFound  
         GOTO step_2_fail
      END

      -- Extended validate        
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,' +  
               ' @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,'+
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'     
            SET @cSQLParam =                          
               '@nMobile      INT,           ' +      
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +   
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cReceiptKey  NVARCHAR( 10), ' +  
               '@cSKU         NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 20), ' + 
               '@cBatchCode   NVARCHAR( 60), ' + 
               '@cCartonSN    NVARCHAR( 60), ' +
               '@cBottleSN    NVARCHAR( 100),' +
               '@nQTYPICKED   INT,           ' +
               '@nQTYCSN      INT,           ' + 
               '@nErrNo             INT            OUTPUT, ' +  
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Step_2_Fail   
         END  
      END  

      -- Prepare next screen var 
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = ''
      SET @cOutField04 = ''
   
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  

   END  

   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
  
      SET @nScn  = @nScn-1  
      SET @nStep = @nStep-1  
  
      SET @cOutField01 = ''
      SET @cReceiptKey = '' 
      SET @cInField02 = ''
   END  
   GOTO Quit  

   
   Step_2_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cInField02 = '' -- ReceiptKey  
      SET @cSKU = ''   
   END
          
END  
GOTO Quit    

/********************************************************************************                  
Step 3. Scn = 5732.                     
   ASN         (field01, output) 
   SKU         (field02, Output)
   Pallet ID    
   (field03, Input)
********************************************************************************/             
Step_3:                  
BEGIN    
   IF @nInputKey = 1 
   BEGIN
      
      SET @cID = @cInField03

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0  
      BEGIN  
         SET @nErrNo = 150514  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_3_Fail  
      END 

      -- Extended validate        
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,' +  
               ' @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,'+
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'     
            SET @cSQLParam =                          
               '@nMobile      INT,           ' +      
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +   
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cReceiptKey  NVARCHAR( 10), ' +  
               '@cSKU         NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 20), ' + 
               '@cBatchCode   NVARCHAR( 60), ' + 
               '@cCartonSN    NVARCHAR( 60), ' +
               '@cBottleSN    NVARCHAR( 100),' +
               '@nQTYPICKED   INT,           ' +
               '@nQTYCSN      INT,           ' + 
               '@nErrNo             INT            OUTPUT, ' +  
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Step_3_Fail   
         END    
      END 
      
      IF @cDefaultBatchNo ='1'
      BEGIN
         SELECT @cBatchCode=lottable02
         FROM receiptdetail (Nolock)
         where receiptkey=@cReceiptkey
            AND toid=@cid
            AND SKU=@cSKU
      END

      -- Prepare next screen var 
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cID 
      SET @cOutField04 = CASE WHEN @cDefaultBatchNo='1' THEN @cBatchCode ELSE ''END

      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
      
   END
   IF @nInputKey = 0 -- Esc or No  
   BEGIN 
   
      SET @cOutField02 = ''
      SET @cInField02 = ''
      SET @cSKU = ''  
  
      SET @nScn  = @nScn-1  
      SET @nStep = @nStep-1  

   END  
   GOTO Quit

   STEP_3_FAIL:
   BEGIN
       SET @cInField03 = ''
       SET @cID ='' 
   END
END
GOTO Quit

/********************************************************************************                  
Step 4. Scn = 5733.                     
   ASN         (field01, OUTPUT) 
   SKU         (field02, OUTPUT)
   Pallet ID    
   (field03, OUTPUT)
   BATCHCODE
   (field04, INPUT)
********************************************************************************/             
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cBatchCode = @cInField04

      IF ISNULL(@cBatchCode,'')=''
      BEGIN
         SET @nErrNo = 150509   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BatchCodeRequire  
         GOTO step_4_fail
      END

      IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) 
                     WHERE Receiptkey= @cReceiptkey
                        AND SKU=@cSKU
                        AND Lottable02=@cBatchCode)
      BEGIN
         SET @nErrNo = 150510  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BatchCodeRequire  
         GOTO step_4_fail
      END

       -- Extended validate        
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,' +  
               ' @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,'+
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'     
            SET @cSQLParam =                          
               '@nMobile      INT,           ' +      
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +   
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cReceiptKey  NVARCHAR( 10), ' +  
               '@cSKU         NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 20), ' + 
               '@cBatchCode   NVARCHAR( 60), ' + 
               '@cCartonSN    NVARCHAR( 60), ' +
               '@cBottleSN    NVARCHAR( 100),' +
               '@nQTYPICKED   INT,           ' +
               '@nQTYCSN      INT,           ' + 
               '@nErrNo             INT            OUTPUT, ' +  
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Step_4_Fail   
         END  
      END  

      SET @cOutField04=@cBatchCode
      SET @nScn  = @nScn+1  
      SET @nStep = @nStep+1 

   END
   IF @nInputKey = 0
   BEGIN 
      -- Prepare next screen var 
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = ''
      SET @cInField03 = ''
      SET @cID = ''  
  
      SET @nScn  = @nScn-1  
      SET @nStep = @nStep-1 
   END
   GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cBatchCode =''
      SET @cInField04 =''
   END
END
GOTO QUIT


/********************************************************************************                  
Step 5. Scn = 5734.                     
   Carton SN:
   (field05, INPUT)
********************************************************************************/ 
STEP_5:
BEGIN

   IF @nInputKey = 1
   BEGIN
      SET @cCartonSN =@cInField05

      IF ISNULL(@cCartonSN,'')=''
      BEGIN
         SET @nErrNo = 150511   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonSNRequire  
         GOTO step_5_fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'cartonid', @cCartonSN) = 0  
      BEGIN  
         SET @nErrNo = 150519 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO step_5_fail  
      END 

      IF EXISTS (SELECT 1 FROM TRACKINGID (NOLOCK) WHERE parenttrackingid=@cCartonSN)
      BEGIN
         SET @nErrNo = 150517   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonScanned  
         GOTO step_5_fail
      END

      SELECT @nQTYCSN = CaseCNT
      FROM PACK WITH (NOLOCK)
      WHERE packkey= (SELECT packkey FROM SKU (NOLOCK) WHERE SKU=@csku and storerkey=@cStorerKey)

      SELECT @nQTYPICKED=SUM(QTY)
      FROM  TRACKINGID (NOLOCK)
      WHERE TrackingID=@cCartonSN
         AND Storerkey =@cStorerKey
         AND SKU= @cSKU
         AND userdefine01=@cReceiptKey
         AND userdefine02=@cID

       -- Extended validate        
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,' +  
               ' @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,'+
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'     
            SET @cSQLParam =                          
               '@nMobile      INT,           ' +      
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +   
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cReceiptKey  NVARCHAR( 10), ' +  
               '@cSKU         NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 20), ' + 
               '@cBatchCode   NVARCHAR( 60), ' + 
               '@cCartonSN    NVARCHAR( 60), ' +
               '@cBottleSN    NVARCHAR( 100),' +
               '@nQTYPICKED   INT,           ' +
               '@nQTYCSN      INT,           ' + 
               '@nErrNo             INT            OUTPUT, ' +  
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Step_5_Fail   
         END  
      END 

      SET @cOutField05 = @cCartonSN
      SET @cOutField06 = CASE WHEN(ISNULL(@nQTYPICKED,''))='' THEN 0 ELSE @nQTYPICKED END
      SET @cOutField07 = @nQTYCSN
  
      SET @nScn  = @nScn+1  
      SET @nStep = @nStep+1 
   END

    IF @nInputKey = 0
   BEGIN
    -- Prepare next screen var 
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cID
      SET @cOutField04 = ''
      SET @cInField04 = ''
      SET @cBatchCode = ''  
  
      SET @nScn  = @nScn-1  
      SET @nStep = @nStep-1 
   END
   GOTO Quit

   step_5_fail:
   BEGIN
      SET @cCartonSN =''
      SET @cInField05 =''
   END
END
GOTO QUIT

/********************************************************************************                  
Step 6. Scn = 5734.                     
   Carton SN:
   (field05, OUTPUT)
   Bottle SN:
   (V_MAX, INPUT)
   (field06, OUTPUT)/   (field07, OUTPUT)
********************************************************************************/ 
STEP_6:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cBottleSN =@cMax

      IF ISNULL(@cBottleSN,'')=''
      BEGIN
         SET @nErrNo = 150512   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --@cBottleSNRequire  
         GOTO step_6_fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'bottleSN', @cBottleSN) = 0  
      BEGIN  
         SET @nErrNo = 150520 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO step_6_fail  
      END 

      IF EXISTS (SELECT 1 FROM TRACKINGID (NOLOCK) WHERE TRACKINGID=@cBottleSN)
      BEGIN
         SET @nErrNo = 150518   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BottleScanned  
         GOTO step_6_fail
      END

      IF (@nQTYCSN = @nQTYPICKED)
      BEGIN
         SET @nErrNo = 150515   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYNotBalance  
         GOTO step_6_fail
      END 

      -- Extended validate        
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,' +  
               ' @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,@cUOM,'+
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'     
            SET @cSQLParam =                          
               '@nMobile      INT,           ' +      
               '@nFunc        INT,           ' +  
               '@cLangCode    NVARCHAR( 3),  ' +  
               '@nStep        INT,           ' +  
               '@nInputKey    INT,           ' +  
               '@cFacility    NVARCHAR( 5),  ' +   
               '@cStorerKey   NVARCHAR( 15), ' +  
               '@cReceiptKey  NVARCHAR( 10), ' +  
               '@cSKU         NVARCHAR( 20), ' + 
               '@cID          NVARCHAR( 20), ' + 
               '@cBatchCode   NVARCHAR( 60), ' + 
               '@cCartonSN    NVARCHAR( 60), ' +
               '@cBottleSN    NVARCHAR( 100),' +
               '@nQTYPICKED   INT,           ' +
               '@nQTYCSN      INT,           ' + 
               '@cUOM         NVARCHAR(5),   ' + 
               '@nErrNo             INT            OUTPUT, ' +  
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSKU, @cID,@cBatchCode,@cCartonSN,@cBottleSN,@nQTYPICKED,@nQTYCSN,@cPUOM,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Step_2_Fail   
         END  
      END  
      ELSE
      BEGIN
         INSERT INTO TRACKINGID (TrackingID,storerkey,SKU,UOM,QTY,PARENTTRACKINGID,userdefine01,userdefine02,userdefine03)
         VALUES(@cBottleSN,@cStorerKey,@cSKU,@cPUOM,'1',@cCartonSN,@cReceiptKey,@cID,@cBatchCode)

         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 150513   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --@cBottleSNRequire  
            GOTO step_6_fail
         END
      END
      
      SELECT @nQTYPICKED=SUM(QTY)
      FROM  TRACKINGID (NOLOCK)
      WHERE PARENTTRACKINGID=@cCartonSN
         AND Storerkey =@cStorerKey
         AND SKU= @cSKU
         AND userdefine01=@cReceiptKey
         AND userdefine02=@cID

      SET @cOutField06=CASE WHEN ISNULL(@nQTYPICKED,'')='' THEN 0 ELSE @nQTYPICKED END

      SET @cMax=''
      SET @cBottleSN=''
   END

   IF @nInputKey = 0
   BEGIN
      IF (@nQTYCSN <> @nQTYPICKED) AND ( ISNULL(@nQTYPICKED,'') NOT IN ('',0))
      BEGIN
         SET @nErrNo = 150516   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotShortPick  
         GOTO step_6_fail
      END 
      ELSE 
      BEGIN
         -- Prepare next screen var 
         SET @cOutField01 = @cReceiptKey 
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = @cID
         SET @cOutField04 = ''
         SET @cInField04 = ''
         SET @cOutField05=''
         SET @cCartonSN = ''  
  
         SET @nScn  = @nScn-1  
         SET @nStep = @nStep-1 
      END         
   END
   GOTO Quit

   STEP_6_FAIL:
   BEGIN
      SET @cMax=''
      SET @cBottleSN=''
   END
END
GOTO QUIT

/********************************************************************************  
Step 7. Screen = 3570. Multi SKU  
   SKU         (Field01)  
   SKUDesc1    (Field02)  
   SKUDesc2    (Field03)  
   SKU         (Field04)  
   SKUDesc1    (Field05)  
   SKUDesc2    (Field06)  
   SKU         (Field07)  
   SKUDesc1    (Field08)  
   SKUDesc2    (Field09)  
   Option      (Field10, input)  
********************************************************************************/  
Step_7:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,  
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  
         'CHECK',  
         @cMultiSKUBarcode,  
         @cStorerKey,  
         @cSKU     OUTPUT,  
         @nErrNo   OUTPUT,  
         @cErrMsg  OUTPUT  
  
      IF @nErrNo <> 0  
      BEGIN  
         IF @nErrNo = -1  
            SET @nErrNo = 0  
         GOTO Quit  
      END  
  
   END  
  
   -- Init next screen var  
   SET @cOutField01 = @cReceiptKey  
   SET @cOutField02 = @cSKU -- SKU  
  
   -- Go to SKU QTY screen  
   SET @nScn = @nFromScn  
   SET @nStep = @nStep - 5  
  
END  
GOTO Quit      
                  

/********************************************************************************                  
Quit. Update back to I/O table, ready to be pick up by JBOSS                  
********************************************************************************/                  
Quit:                  
                  
BEGIN                  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET                   
      EditDate       = GETDATE(),               
      ErrMsg         = @cErrMsg,                   
      Func           = @nFunc,                  
      Step           = @nStep,                  
      Scn            = @nScn,                  
                  
      StorerKey      = @cStorerKey,                  
      Facility       = @cFacility,                   
      Printer        = @cPrinter,                         
      InputKey       = @nInputKey,                             
                        
      V_UOM          = @cPUOM, 
      V_MAX          = @cMAX,
      
      V_String1      = @cReceiptKey,        
      V_String2      = @cChkFacility,       
      V_String3      = @cChkStorerKey,      
      V_String4      = @cMultiSKUBarcode,   
      V_String5      = @cExtendedValidateSP,
      V_String6      = @cExtendedUpdateSP,
      V_String7      = @cID,
      V_String8      = @cBatchCode,
      V_String9      = @cCartonSN,
      V_String10     = @cSKU,
      V_String11     = @cDefaultBatchNo,

      V_String20     = @nFromScn,

      V_Integer1     = @nQTYPICKED,
      V_Integer2     = @nQTYCSN,
      
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
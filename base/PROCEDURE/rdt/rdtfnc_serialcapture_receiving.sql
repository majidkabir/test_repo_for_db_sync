SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/    
/* Store procedure: rdtfnc_SerialCapture_Receiving                           */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: SOS#208972 - Receiving By Serial No                              */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2011-03-21 1.0  ChewKP   Created                                          */ 
/* 2016-09-30 1.1  Ung      Performance tuning                               */   
/* 2018-11-15 1.2  Gan      Performance tuning                               */
/*****************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_SerialCapture_Receiving](    
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
   @cPrinter_Paper      NVARCHAR(10),    
   @cUserName           NVARCHAR(18),    
    
   @cStorerKey          NVARCHAR(15),    
   @cFacility           NVARCHAR(5),    
   @cReceiptMethod      NVARCHAR(10),
   @cReceiptkey         NVARCHAR(10),
   @cDescription        NVARCHAR(10),
   @cChkFacility        NVARCHAR(5),     
   @nRowCount           INT,
   @cChkReceiptKey      NVARCHAR(10),    
   @cReceiptStatus      NVARCHAR(10),    
   @cChkStorerKey       NVARCHAR(15),   
   @cLOC                NVARCHAR(10),
   @cOption             NVARCHAR(1),
   @nCountCase          INT,
   @nCountPallet        INT,
   @nCountBottle        INT,
   @cSerialNo           NVARCHAR(20),
   @cExternPOKey        NVARCHAR(20),
   @cPackkey            NVARCHAR(10),
   @nSumSerialScanned   INT,
   
   
    
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
   @cPrinter_Paper   = Printer_Paper,     
   @cUserName        = UserName,    
    
   @cReceiptkey      = V_Receiptkey,    
   @cLoc             = V_Loc,
   @cReceiptMethod   = V_String1,
   @cDescription     = V_String2,
   @cExternPOKey     = V_String3,  

   
          
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
IF @nFunc = 577
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 577
   IF @nStep = 1 GOTO Step_1   -- Scn = 2750 ReceiptKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 2751 ToLoc
   IF @nStep = 3 GOTO Step_3   -- Scn = 2752 Receipt Method
   IF @nStep = 4 GOTO Step_4   -- Scn = 2753 Serial No
   
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from menu (func = 1664)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn  = 2750    
   SET @nStep = 1    
    
   -- initialise all variable    
   SET @cDescription = 'TOTAL'
   
    
   -- Prep next screen var       
   SET @cOutField01 = ''     
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. screen = 2750    
   ASN: (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cReceiptKey = ISNULL(RTRIM(@cInField01),'')
      
      IF @cReceiptKey = '' 
      BEGIN
         SET @nErrNo = 72641    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail      
      END
      
      
      SELECT DISTINCT     
               @cChkFacility = R.Facility,    
               @cChkStorerKey = R.StorerKey,    
               @cReceiptStatus = R.Status    
            FROM dbo.Receipt R WITH (NOLOCK)    
            WHERE R.ReceiptKey = @cReceiptKey    
               AND R.StorerKey = @cStorerkey    
            
      SET @nRowCount = @@ROWCOUNT    
      
      IF @nRowCount < 1 
      BEGIN
         SET @nErrNo = 72642   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN     
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail     
      END
      
      -- Validate ASN in different facility    
      IF @cFacility <> @cChkFacility    
      BEGIN    
         SET @nErrNo = 72643   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN & FAC DIFF'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail   
      END    
    
      -- Validate ASN belong to the storer    
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = ''    
      BEGIN    
         SET @nErrNo = 72644
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN DIFF STORER'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail   
      END    
    
      -- Validate ASN status    
      IF @cReceiptStatus = '9'    
      BEGIN    
         SET @nErrNo = 72645
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN CLOSE'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail   
      END    

      -- Lock Records on ExternPOKey to avoid IML overwrite it --
      SET @cExternPOKey = ''
      SELECT @cExternPOKey = PO.ExternPOKey 
      FROM dbo.Receipt RECEIPT WITH (NOLOCK)
      INNER JOIN dbo.PackConfig PO WITH (NOLOCK) ON PO.ExternPOKey = RECEIPT.ExternReceiptKey AND PO.Storerkey = RECEIPT.Storerkey
      WHERE RECEIPT.Receiptkey = @cReceiptKey
      AND RECEIPT.Storerkey = @cStorerkey


      

      IF ISNULL(@cExternPOKey,'') <> ''
      BEGIN
            UPDATE dbo.PackConfig
            Set Status = '1'
            WHERE ExternPOKey = @cExternPOKey   
            AND Storerkey = @cStorerkey

            IF @@ERROR <> 0 
            BEGIN
                  SET @nErrNo = 72659
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackCfgFailed'    
                  EXEC rdt.rdtSetFocusField @nMobile, 1    
                  GOTO Step_1_Fail   
            END  
      END
      ELSE
      BEGIN
            SET @nErrNo = 72660
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No PackCfg'    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_1_Fail   
      END
    
          
      SET @cOutField01 = ''
      
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
      
      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '1', -- Sign In
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cReceiptKey   = @cReceiptKey,
           --@cRefNo1       = @cReceiptKey,
           @nStep         = @nStep
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Release Records on ExternPOKey to let IML overwrite it --
      IF ISNULL(@cExternPOKey,'') <> ''
      BEGIN
            UPDATE dbo.PackConfig
            Set Status = '0'
            WHERE ExternPOKey = @cExternPOKey   
            AND Storerkey = @cStorerkey
            AND Status = '1'

            IF @@ERROR <> 0 
            BEGIN
                  SET @nErrNo = 72659
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackCfgFailed'    
                  EXEC rdt.rdtSetFocusField @nMobile, 1    
                  GOTO Step_1_Fail   
            END  
      END

       -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '9', -- Sign Out
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cReceiptKey   = @cReceiptKey,
           --@cRefNo1       = @cReceiptKey,
           @nStep         = @nStep

      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
    
      SET @cOutField01 = ''    
     
      
 
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cReceiptKey = ''    
      SET @cOutField01 = ''    
      
    END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. screen = 2751    
   ToLoc (Field01)

********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      
      SET @cLOC = ISNULL(@cInField01,'') -- LOC    
    
      -- Validate compulsary field    
      IF @cLOC = '' 
      BEGIN    
         SET @nErrNo = 72646
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
      
      -- Get the location    
      DECLARE @cChkLOC NVARCHAR( 10)    
      SELECT     
         @cChkLOC = LOC,     
         @cChkFacility = Facility    
      FROM dbo.LOC WITH (NOLOCK)    
      WHERE LOC = @cLOC    
    
      -- Validate location    
      IF @cChkLOC IS NULL OR @cChkLOC = ''    
      BEGIN    
         SET @nErrNo = 72647
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv LOC'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
    
      -- Validate location not in facility    
      IF @cChkFacility <> @cFacility    
      BEGIN    
         SET @nErrNo = 72648
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Facility'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
      


    
            
      
      SET @cOutField01 = ''
        
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
      
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cReceiptKey
      --SET @cOutField02 = ''
    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cLOC = ''
      SET @cOutField01 = ''    
   END    
    
END    
GOTO Quit    

/********************************************************************************    
Step 3. screen = 2752    
   Option (Field01, Input) Receive By Method:
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      
       --screen mapping            
      SET @cOption = ISNULL(@cInField01,'')      
      
      
            
      IF ISNULL(RTRIM(@cOption), '') = '' 
      BEGIN            
         SET @nErrNo = 72649            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1            
         GOTO Step_3_Fail            
      END            
            
      IF ISNULL(RTRIM(@cOption), '') <> '1' AND ISNULL(RTRIM(@cOption), '') <> '2'  AND ISNULL(RTRIM(@cOption), '') <> '3' 
      BEGIN            
         SET @nErrNo = 72650            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Option' 
         EXEC rdt.rdtSetFocusField @nMobile, 1               
         GOTO Step_3_Fail 
                  
      END       
      
--      SELECT @nCountCase   = COUNT(ISNULL(Userdefine01,0)),  -- CASE
--             @nCountPallet = COUNT(ISNULL(Userdefine02,0)),  -- PALLET 
--             @nCountBottle = COUNT(ISNULL(Userdefine03,0))   -- BOTTLE
--      FROM dbo.ReceiptDetail WITH (NOLOCK)
--      WHERE ReceiptKey = @cReceiptKey
--            AND Storerkey = @cStorerkey
            
      SET @nCountCase = 0
      SELECT @nCountCase  = COUNT (DISTINCT Userdefine01) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE  ReceiptKey = @cReceiptKey
      AND Storerkey = @cStorerkey
      AND  Userdefine01 <> ''      
      
      SET @nCountPallet = 0
      SELECT @nCountPallet  = COUNT (DISTINCT Userdefine02) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE  ReceiptKey = @cReceiptKey
      AND Storerkey = @cStorerkey
      AND  Userdefine02 <> ''    

      
      SET @nCountBottle = 0
      SELECT @nCountCase  = COUNT (DISTINCT Userdefine02) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE  ReceiptKey = @cReceiptKey
      AND Storerkey = @cStorerkey
      AND  Userdefine03 <> ''    

      
      IF @cOption = '1'
      BEGIN
         SET @cReceiptMethod = 'UOM4'
         SET @cOutField01 = 'PALLET'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'PALLET' + ':' + CAST(ISNULL(@nCountPallet,0) as NVARCHAR(5))
      END
      ELSE IF @cOption = '2'
      BEGIN
         SET @cReceiptMethod = 'UOM1'
         SET @cOutField01 = 'CASE'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'CASE' + ':' + CAST(ISNULL(@nCountCase,0) as NVARCHAR(5))
      END
      ELSE IF @cOption = '3'
      BEGIN
         SET @cReceiptMethod = 'UOM3'
         SET @cOutField01 = 'BOTTLE'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'BOTTLE' + ':' + CAST(ISNULL(@nCountBottle,0) as NVARCHAR(5))
      END
      
      SET @cOutField02 = ''
      
        
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1   
      

   END    
   
   IF @nInputKey = 0 -- ESC
   BEGIN    
      SET @cOutField01 = @cLoc
      
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    

   END   
   GOTO QUIT
   
   Step_3_Fail:    
   BEGIN    
      SET @cOption = ''
      SET @cOutField01 = ''    
   END
   
END    
GOTO Quit   

/********************************************************************************    
Step 4. screen = 2753    
   SerialNo (Field01, Input) 
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      
       --screen mapping            
      SET @cSerialNo = ISNULL(@cInField02,'')      
            
      
      IF ISNULL(RTRIM(@cSerialNo), '') = '' 
      BEGIN            
         SET @nErrNo = 72651            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1   
         
         GOTO Step_4_Fail            
      END         
      
         
      SET @cPackkey = ''
      IF @cReceiptMethod = 'UOM4'
      BEGIN
         SELECT @cPackkey = PackKey From dbo.PackConfig WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey 
         AND   UOM4Barcode = @cSerialNo 
         AND   ExternPOKey = @cExternPOKey
            
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE Receiptkey   = @cReceiptKey
                     AND   UserDefine02 = @cSerialNo
                     AND   Storerkey    = @cStorerkey )
         BEGIN
               SET @nErrNo = 72652            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode exist'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   
         
         IF EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM4Barcode = @cSerialNo 
                     AND   Status NOT IN ('0','1')
                     AND   ExternPOkey = @cExternPOKey)
         BEGIN
               SET @nErrNo = 72653            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   

         IF NOT EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM4Barcode = @cSerialNo 
                     AND   ExternPOkey = @cExternPOKey)
         BEGIN
               SET @nErrNo = 72668            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Barcode'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail    
         END


         -- Check If Any Case been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine01 IN ( SELECT UOM1Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM4Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine01 <> ''  )
         BEGIN
               SET @nErrNo = 72665            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END

         -- Check If Any Bottle been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine03 IN ( SELECT UOM3Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM4Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine03 <> ''  )
         BEGIN
               SET @nErrNo = 72666            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END
               
      END
      
      IF @cReceiptMethod = 'UOM1'
      BEGIN
         SELECT @cPackkey = PackKey From dbo.PackConfig WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey 
         AND   UOM1Barcode = @cSerialNo 
         AND   ExternPOKey = @cExternPOKey
            
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE Receiptkey   = @cReceiptKey
                     AND   UserDefine01 = @cSerialNo
                     AND   Storerkey    = @cStorerkey )
         BEGIN
               SET @nErrNo = 72654         
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode exist'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   
         
         IF EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM1Barcode = @cSerialNo 
                     AND   Status NOT IN ('0','1')
                     AND   ExternPOkey = @cExternPOKey)
         BEGIN
               SET @nErrNo = 72655            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END         

         IF NOT EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM1Barcode = @cSerialNo 
                     AND   ExternPOkey = @cExternPOKey)
         BEGIN
               SET @nErrNo = 72667            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Barcode'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail    
         END

         -- Check If Any Pallet been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine02 IN ( SELECT UOM4Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM1Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine02 <> ''  )
         BEGIN
               SET @nErrNo = 72661            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END

         -- Check If Any Bottle been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine03 IN ( SELECT UOM3Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM1Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine03 <> '' )
         BEGIN
               SET @nErrNo = 72663            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END

         
         
      END
      
      IF @cReceiptMethod = 'UOM3'
      BEGIN
         SELECT @cPackkey = PackKey From dbo.PackConfig WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey 
         AND   UOM3Barcode = @cSerialNo 
         AND   ExternPOKey = @cExternPOKey
      
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE Receiptkey   = @cReceiptKey
                     AND   UserDefine03 = @cSerialNo
                     AND   Storerkey    = @cStorerkey )
         BEGIN
               SET @nErrNo = 72656         
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode exist'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   
         
         IF EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM3Barcode = @cSerialNo 
                     AND   Status NOT IN ('0','1')
                     AND   ExternPOkey = @cExternPOKey   )
         BEGIN
               SET @nErrNo = 72657            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   

         IF NOT EXISTS ( SELECT 1 FROM dbo.PackConfig WITH (NOLOCK)
                     WHERE Storerkey = @cStorerkey 
                     AND   UOM3Barcode = @cSerialNo 
                     AND   ExternPOkey = @cExternPOKey)
         BEGIN
               SET @nErrNo = 72669         
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Barcode'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail    
         END

         -- Check If Any Pallet Barcode been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine02 IN ( SELECT UOM4Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM3Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine02 <> ''  )
         BEGIN
               SET @nErrNo = 72662            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   

         -- Check If Any Case Barcode been scanned before
         IF EXISTS ( SELECT * FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE UserDefine01 IN ( SELECT UOM1Barcode FROM dbo.PackConfig 
                                             WHERE Storerkey = @cStorerkey        
                                             AND ExternPOKey = @cExternPOKey
                                             AND UOM3Barcode = @cSerialNo )
                     AND ReceiptKey = @cReceiptKey
                     AND Storerkey  = @cStorerkey   
                     AND UserDefine01 <> ''  )
         BEGIN
               SET @nErrNo = 72664            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Barcode Scanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
         END   

         
      END
      
      -- Verify PAckkey Exist
      IF NOT EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK)
                     WHERE PackKey = @cPackkey )
      BEGIN
             SET @nErrNo = 72658            
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Packkey'    
             EXEC rdt.rdtSetFocusField @nMobile, 1   
             GOTO Step_4_Fail   
      END
      

      

      -- Insert ReceiptDetail --
      EXEC [RDT].[rdt_SerialCapture_ConfirmTask]
        @nMobile 
       ,@cLangCode
       ,@cStorerKey
       ,@cUserName 
       ,@cFacility 
       ,@cReceiptKey
       ,@cSerialNo  
       ,@cLOC       
       ,@cReceiptMethod
       ,@cExternPOKey
       ,@nErrNo            OUTPUT
       ,@cErrMsg           OUTPUT -- screen limitation, 20 char max

    

      IF @nErrNo <> 0
      BEGIN
          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               --EXEC rdt.rdtSetFocusField @nMobile, 1   
               GOTO Step_4_Fail   
      END   
      
      SET @nSumSerialScanned = 0

      IF @cReceiptMethod = 'UOM4'
      BEGIN     
         SET @nCountPallet = 0
         SELECT @nCountPallet  = COUNT (DISTINCT Userdefine02) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE  ReceiptKey = @cReceiptKey
         AND Storerkey = @cStorerkey
         AND  Userdefine02 <> ''    

         SET @cOutField01 = 'PALLET'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'PALLET' + ':' + CAST(ISNULL(@nCountPallet,0) as NVARCHAR(5)) 
         
      END
      
      IF @cReceiptMethod = 'UOM1'
      BEGIN
         SET @nCountCase = 0
         SELECT @nCountCase  = COUNT (DISTINCT Userdefine01) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE  ReceiptKey = @cReceiptKey
         AND Storerkey = @cStorerkey
         AND  Userdefine01 <> ''     
         
         SET @cOutField01 = 'CASE'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'CASE' + ':' + CAST(ISNULL(@nCountCase,0) as NVARCHAR(5))
      END
      
      
      IF @cReceiptMethod = 'UOM3'
      BEGIN
         SET @nCountBottle = 0
         SELECT @nCountBottle  = COUNT (DISTINCT Userdefine03) FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE  ReceiptKey = @cReceiptKey
         AND Storerkey = @cStorerkey
         AND  Userdefine03 <> ''   


         
         
         SET @cOutField01 = 'BOTTLE'
         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'BOTTLE' + ':' + CAST(ISNULL(@nCountBottle,0) as NVARCHAR(5))
      END
      
--       IF @cOption = '1'
--      BEGIN
--         SET @cReceiptMethod = 'UOM4'
--         SET @cOutField01 = 'PALLET'
--         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'PALLET' + ':' + CAST(ISNULL(@nCountPallet,0) as NVARCHAR(5))
--      END
--      ELSE IF @cOption = '2'
--      BEGIN
--         SET @cReceiptMethod = 'UOM1'
--         SET @cOutField01 = 'CASE'
--         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'CASE' + ':' + CAST(ISNULL(@nCountCase,0) as NVARCHAR(5))
--      END
--      ELSE IF @cOption = '3'
--      BEGIN
--         SET @cReceiptMethod = 'UOM3'
--         SET @cOutField01 = 'BOTTLE'
--         SET @cOutField03 = ISNUll(RTRIM(@cDescription),'') + ' ' + 'BOTTLE' + ':' + CAST(ISNULL(@nCountBottle,0) as NVARCHAR(5))
--      END
      
--      
--      IF @cReceiptMethod = 'UOM4'
--      BEGIN     
--         SELECT @nSumSerialScanned = Count(DISTINCT UOM4BarCode) 
--         FROM PackConfig WITH (NOLOCK)
--         WHERE Storerkey = @cStorerKey
--         AND ExternPOKey = @cExternPOKey
--         AND STatus = '5'
--      END
--
--      IF @cReceiptMethod = 'UOM1'
--      BEGIN     
--         SELECT @nSumSerialScanned = Count(DISTINCT UOM1BarCode) 
--         FROM PackConfig WITH (NOLOCK)
--         WHERE Storerkey = @cStorerKey
--         AND ExternPOKey = @cExternPOKey
--         AND STatus = '5'
--      END
--
--      IF @cReceiptMethod = 'UOM3'
--      BEGIN     
--         SELECT @nSumSerialScanned = Count(DISTINCT UOM3BarCode) 
--         FROM PackConfig WITH (NOLOCK)
--         WHERE Storerkey = @cStorerKey
--         AND ExternPOKey = @cExternPOKey
--         AND STatus = '5'
--      END

      
      --SET @cOutField03 = 'TTL RCV: ' + CAST(@nSumSerialScanned AS NVARCHAR(5))
      SET @cOutField02 = ''
      
      

   END    
   
   IF @nInputKey = 0 -- ESC
   BEGIN    
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    

   END   
   GOTO QUIT
   
   Step_4_Fail:    
   BEGIN    
      SET @cSerialNo = ''
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
       Printer_Paper = @cPrinter_Paper,     
       -- UserName      = @cUserName,    
       
       V_Receiptkey  = @cReceiptkey,    
       V_Loc         = @cLoc,
       V_String1     = @cReceiptMethod,
       V_String2     = @cDescription,
       V_String3     = @cExternPOKey,
    
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
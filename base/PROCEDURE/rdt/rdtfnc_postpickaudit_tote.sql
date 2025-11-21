SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/   
/* Copyright: IDS                                                             */   
/* Purpose: Tote Post Pick Audit SOS#247806                                   */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2012-09-19 1.0  ChewKP     Created                                         */   
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-11-08 1.2  Gan        Performance tuning                              */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_PostPickAudit_Tote] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE   
   @cOption     NVARCHAR( 1),  
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
     
   @cToteNo       NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @cPUOM_Desc    NVARCHAR( 5),
   @cMUOM_Desc    NVARCHAR( 5),
   @nPUOM_Div     INT, -- UOM divider
   @cOptions      NVARCHAR( 1),
   @nSumPackQty   INT,
   @cPickSlipNo   NVARCHAR(10),
   @cPUOM         NVARCHAR( 1), -- Prefer UOM
   @nCQTY         INT,
   @nSKUCnt       INT,
   @nSumPPAQty    INT,
   @b_Success     INT,
   
        
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
   
   @nCQTY      = V_Integer1,
  
   @cToteNo    = V_String1,
  -- @nCQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,
   @cPickSlipNo = V_String3,
   
   
   
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
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
Declare @n_debug INT  
  
SET @n_debug = 0  
  
  
  
IF @nFunc = 847  -- Tote Receiving  
BEGIN  
   -- Redirect to respective screen  
 IF @nStep = 0 GOTO Step_0   -- Tote Receiving
 IF @nStep = 1 GOTO Step_1   -- Scn = 3190. To Loc
 IF @nStep = 2 GOTO Step_2   -- Scn = 3191. Pallet ID  
 IF @nStep = 3 GOTO Step_3   -- Scn = 3192. Sucess Message
   
   
     
END  

RETURN -- Do nothing if incorrect step

  
/********************************************************************************  
Step 0. func = 847. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   
   -- Initiate var  
    -- EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey  ,
     @nStep       = @nStep
  
   
   -- Init screen  
   SET @cOutField01 = ''   
   SET @cToteNo = ''
   SET @nCQTY = 0
   SET @cPickSlipNo = ''
   
           
   -- Set the entry point  
   SET @nScn = 3190  
   SET @nStep = 1  
   
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 3190.   
   Tote (Input , Field01)  
     
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      
       
      SET @cToteNo = ISNULL(RTRIM(@cInField01),'')  
      
      IF @cToteNo = '' OR @cToteNo IS NULL
      BEGIN
         SET @nErrNo = 77001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Tote Req'
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cToteNo 
                     AND ManifestPrinted = 'Y'
                     AND LabelPrinted = 'Y'
                     --AND DropIDType = 'PIECE'
                     AND Status = '0' ) 
      BEGIN
         SET @nErrNo = 77002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Tote'
         GOTO Step_1_Fail
      END        
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE LabelNo = @cToteNo
                      AND StorerKey = @cStorerKey )
      BEGIN
         SET @nErrNo = 77003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Tote'
         GOTO Step_1_Fail
      END             
      
      -- Delete PPA when record exist with Status = '9'
      DELETE FROM rdt.rdtPPA 
      WHERE DropID = @cToteNo
      AND Status = '9'
      
        
      
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cToteNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
        
      -- GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
       
       
    
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
   END
     
  
END   
GOTO QUIT  
  
/********************************************************************************  
Step 2. Scn = 3191.   
   Tote    (field01)
   SKU     (field02, input)  
   Options (field03, input)
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      
       
      SET @cSKU = ISNULL(RTRIM(@cInField02),'')  
      SET @cOptions = ISNULL(RTRIM(@cInField03),'')  
      
      IF @cSKU = '' AND @cOptions = ''
      BEGIN
               SET @nErrNo = 77009
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Input Require'
               GOTO Step_2_Fail
      END
      
      IF @cOptions <> ''
      BEGIN
            IF @cOptions <> '9'
            BEGIN
               SET @nErrNo = 77008
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
               GOTO Step_2_Fail
            END
      END
      
      
      
      IF @cSKU <> ''
      BEGIN
      
--         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
--                         WHERE LabelNo   = @cToteNo
--                         AND   SKU       = @cSKU
--                         AND   StorerKey = @cStorerKey )   
--         BEGIN
--            SET @nErrNo = 77004
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
--            GOTO Step_2_Fail
--         END
         
         EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey       
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 77010
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO Step_2_Fail
         END
         
         EXEC dbo.nspg_GETSKU
            @cStorerKey  
         ,  @cSKU       OUTPUT
         ,  @b_Success  OUTPUT
         ,  @nErrNo     OUTPUT
         ,  @cErrMsg    OUTPUT

      	IF @b_success = 0
      	BEGIN
            SET @nErrNo = 77011
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_2_Fail
         END
         
         
         SET @nSumPackQty = 0
         SET @cPickSlipNo = ''
         
         SELECT @nSumPackQty = SUM(PD.Qty)
               ,@cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.LabelNo   = @cToteNo
         AND   PD.SKU       = @cSKU
         AND   PD.StorerKey = @cStorerKey
         Group By PickSlipNo
         
         
         SELECT @cSKUDescr = '', @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0

         SELECT
               @cSKUDescr = SKU.Descr,
               @cMUOM_Desc = Pack.PackUOM3,
               @cPUOM_Desc =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU
         
         IF NOT EXISTS (SELECT 1 FROM rdt.RDTPPA WITH (NOLOCK)
                    WHERE DropID     = @cToteNo
                    AND   PickSlipNo = @cPickSlipNo
                    AND   SKU        = @cSKU
                    AND   UserName   = @cUserName
                    AND   StorerKey  = @cStorerKey
                    AND   Status     <> '9')
         BEGIN
            
            -- Insert into PPA 
            SET @nCQTY = 1
            
            
            INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
            VALUES ('', @cPickSlipNo, '', '', @cStorerKey, @cSKU, @cSKUDescr, @nSumPackQty, @nCQTY, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, '', @cToteNo)  
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77005
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PPA Failed'
               GOTO Step_2_Fail
            END
            
         END
         ELSE
         BEGIN
            SET @nCQTY = @nCQTY + 1
            
            UPDATE rdt.rdtPPA
            SET CQty = @nCQty
            WHERE DropID      = @cToteNo
             AND   PickSlipNo = @cPickSlipNo
             AND   SKU        = @cSKU
             AND   UserName   = @cUserName
             AND   StorerKey  = @cStorerKey 
             AND   Status    <> '9'
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77006
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PPA Failed'
               GOTO Step_2_Fail
            END
            
            
         END   
      END
      
      
      
      IF @cOptions = '9'
      BEGIN
         
         UPDATE rdt.rdtPPA
         SET Status = '9'
         WHERE DropID      = @cToteNo
          AND   UserName   = @cUserName
          AND   StorerKey  = @cStorerKey 
          AND   Status    <> '9'
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77007
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PPA Failed'
            GOTO Step_2_Fail
         END
          
          SET @nSumPackQty = 0
          SET @nSumPPAQty = 0
          SET @cPickSlipNo = ''
         
          SELECT @nSumPackQty = SUM(PD.Qty)
          FROM dbo.PackDetail PD WITH (NOLOCK)
          WHERE PD.LabelNo   = @cToteNo
          AND   PD.StorerKey = @cStorerKey
          Group By PD.LabelNo
          
          SELECT @nSumPPAQty = SUM(CQty)
          FROM rdt.rdtPPA  WITH (NOLOCK)
          WHERE DropID   = @cToteNo
          AND   StorerKey = @cStorerKey
          Group by DropID
          
          -- GOTO Next Screen  
          
          IF ISNULL(@nSumPackQty,0) <> ISNULL(@nSumPPAQty,0)
          BEGIN
            SET @cOutField02 = 'WITH VARIANCE'
          END
          ELSE
          BEGIN
            SET @cOutField02 = ''
          END
          
          SET @nScn = @nScn + 1  
          SET @nStep = @nStep + 1  
          
          
          
          GOTO QUIT
      END
      
      
      
      
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      -- EventLog -   
      EXEC RDT.rdt_STD_EventLog  
        @cActionType = '3', -- 
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey, 
        @cDropID     = @cToteNo,
        --@cRefNo1     = @cToteNo,
        @cSKU        = @cSKU,
        @nStep       = @nStep
       
    
   END  -- Inputkey = 1  
  
  
   IF @nInputKey = 0   
   BEGIN  
      
      -- Prepare Next Screen Variable  
      SET @cOutField01 = ''
      SET @cOutField02 = ''  
      
        
      -- GOTO Previous Screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   STEP_2_FAIL:  
   BEGIN  
      
      SET @cOutField02 = ''
      SET @cOutField03 = ''  
      
   END  
     

END   
GOTO QUIT  
  
  
/********************************************************************************  
Step 3. Scn = 3192.   
     
   Tote    (field01)  
   Message
     
********************************************************************************/  
Step_3:  
BEGIN  
    IF @nInputKey = 1 OR  @nInputKey = 0  --ENTER / ESC
    BEGIN  
      
      SET @cToteNo = ''
      SET @nCQTY = 0
      SET @cSKU  = ''
            
      -- Prepare Next Screen Variable  
      SET @cOutField01 = ''
        
      --GOTO Next Screen  
      SET @nScn = @nScn - 2  
      SET @nStep = @nStep - 2  
   
         
    END  -- Inputkey = 1  
  
END   
GOTO QUIT  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
  
BEGIN  
 UPDATE RDTMOBREC WITH (ROWLOCK) SET   
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,   
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,   
      Printer   = @cPrinter,   
      -- UserName  = @cUserName,  
      InputKey  = @nInputKey,  
      
      V_Integer1 = @nCQTY,
    
      V_String1 = @cToteNo,
      --V_String2 = @nCQTY,
      V_String3 = @cPickSlipNo,
        
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
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Carton_Consolidation                              */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Carton Consolidation                                             */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-01-06 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-31 1.2  TungGH   Performance                                      */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Carton_Consolidation](
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
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
  

   @cFromCarton         NVARCHAR(18),
   @cToCarton           NVARCHAR(18),
   @cPickSlipNo         NVARCHAR(10),
   @cPackkey            NVARCHAR(10),  
   @cPackUOM03          NVARCHAR(10),       
   @cSKU                NVARCHAR(20),  
   @cOption             NVARCHAR(1),
   @cInSKU              NVARCHAR(20),
   @c_ErrMsg            NVARCHAR(20),
   @cQtyMV              NVARCHAR(5),

   @nPrevStep           INT,
   @nPrevScn            INT,
   @nQtyAvl             INT,      
   @nQtyMV              INT,
   @n_Err               INT,
   @nSKUCnt             INT,

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
   
   @cSKU             = V_SKU,
   @cPackUOM03       = V_UOM,
   @cPickSlipNo      = V_String1,
   @cFromCarton      = V_String2,
   @cPackkey         = V_String3,
   @cToCarton        = V_String6,
   @cOption          = V_String7,
   
   @nQtyAvl          = V_Integer1,
   @nQtyMV           = V_Integer2,
      
   @nPrevStep        = V_FromStep,
   @nPrevScn         = V_FromScn,
      
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
IF @nFunc = 990
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 973
   IF @nStep = 1 GOTO Step_1   -- Scn = 1060  From Tote
   IF @nStep = 2 GOTO Step_2   -- Scn = 1061  SKU/UPC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1062  Qty MV
   IF @nStep = 4 GOTO Step_4   -- Scn = 1063  To Tote
   IF @nStep = 5 GOTO Step_5   -- Scn = 1064  To Tote ( For Move by Whole Tote )
   IF @nStep = 6 GOTO Step_6   -- Scn = 1065  Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 973)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 1060
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
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
   SET @cOutField12 = '' 
   SET @cOutField13 = '' 
   SET @cOutField14 = '' 
   SET @cOutField15 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2460
   PICKSLIP NO (Field01, input)
   FROM TOTE   (Field02, input)
   OPTION      (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo  = ISNULL(@cInField01,'')
      SET @cFromCarton  = ISNULL(@cInField02,'')
      SET @cOption      = ISNULL(@cInField03,'')

      IF ISNULL(RTRIM(@cPickSlipNo), '') = ''
      BEGIN
         SET @nErrNo = 71966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSlip Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         SET @cOutField02 = @cFromCarton
         SET @cOutField03 = @cOption
         GOTO Quit
      END 

      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 71967
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv PSlip
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         SET @cOutField02 = @cFromCarton
         SET @cOutField03 = @cOption
         GOTO Quit
      END 

      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail PD WITH (NOLOCK) 
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipno
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey = @cStorerKey
            AND O.Status NOT IN ('CANC', '9'))
      BEGIN
         SET @nErrNo = 71968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORD Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         SET @cOutField02 = @cFromCarton
         SET @cOutField03 = @cOption
         GOTO Quit
      END 

      IF ISNULL(RTRIM(@cFromCarton), '') = ''
      BEGIN
         SET @nErrNo = 71969
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CARTON Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = ''
         SET @cOutField03 = @cOption
         GOTO Quit
      END 

      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND DropID = @cFromCarton)
      BEGIN
         SET @nErrNo = 71970
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv CARTON 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = ''
         SET @cOutField03 = @cOption
         GOTO Quit
      END 

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 71971
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OPTION Req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cFromCarton
         SET @cOutField03 = ''
         GOTO Quit
      END 

      IF ISNULL(RTRIM(@cOption), '') NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 71972
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OPTION 
         EXEC rdt.rdtSetFocusField @nMobile, 3
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cFromCarton
         SET @cOutField03 = ''
         GOTO Quit
      END 

      IF @cOption = '2' -- partial
      BEGIN
         SET @cOption = 'P'

         -- Prepare for next screen
         SET @cOutField01 = @cFromCarton
         SET @cOutField02 = ''

         SET @nStep = @nStep + 1 
         SET @nScn  = @nScn + 1

         GOTO Quit 
      END
      ELSE     -- @cOption = 1 full
      BEGIN
         SET @cOption = 'F'

         -- Prepare for next screen
         SET @cOutField01 = @cFromCarton
         SET @cOutField02 = ''

         -- Remember current screen
         SET @nPrevStep = @nStep
         SET @nPrevScn = @nScn

         SET @nStep = @nStep + 4 
         SET @nScn  = @nScn + 4

         GOTO Quit 
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

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
GOTO Quit

/********************************************************************************
Step 2. screen = 1061
   FROM TOTE            (Field01)
   SKU/UPC              (Field02 , Input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInSKU = @cInField02

      IF ISNULL(@cInSKU,'') = ''
      BEGIN
         SET @nErrNo = 71973
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req
         GOTO Step_2_Fail  
      END

      EXEC [RDT].[rdt_GETSKUCNT]    
         @cStorerKey  = @cStorerKey,    
         @cSKU        = @cInSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT
             
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 71974    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'    
         GOTO Step_2_Fail    
      END    
       
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 71975
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_2_Fail    
      END    
     
      EXEC [RDT].[rdt_GETSKU]    
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cInSKU        OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      SET @cSKU = @cInSKU

      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND DropID = @cFromCarton
            AND SKU = @cSKU)
      BEGIN    
         SET @nErrNo = 71976
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU NOT EXISTS'
         GOTO Step_2_Fail    
      END   

      SET @cPackkey = ''
      SELECT @cPackkey = Packkey FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU = @cSKU 
      AND Storerkey = @cStorerkey 

      SET @cPackUOM03 = ''
      SELECT @cPackUOM03 = PackUOM3 FROM dbo.PACK WITH (NOLOCK)
      WHERE Packkey = @cPackkey
	  
      SET @nQtyAvl = 0
     
      SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.StorerKey = @cStorerKey                
         AND PD.DropID = @cFromCarton                 
         AND PD.Qty > 0              
         AND O.Status < '9' 	     
         AND PD.SKU = @cSKU        

      IF @nQtyAvl = 0
      BEGIN    
         SET @nErrNo = 71977
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO QTY TO MOVE'
         GOTO Step_2_Fail    
      END   

      --prepare next screen variable
      SET @cOutField01 = @cFromCarton
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cPackUOM03
      SET @cOutField04 = @nQtyAvl
      SET @cOutField05 = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 1
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
   
      SET @cSKU = ''

      SET @nScn  = @nScn - 1 
      SET @nStep = @nStep - 1
   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cFromCarton
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 1062
 From Tote     (Field01)
 SKU           (Field02)
 UOM           (Field03)
 Qty Avl       (Field04)
 Qty MV        (Field05, Input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
      SET @cQtyMV = ISNULL(@cInField05,0)

      IF @cQtyMV  = ''   SET @cQtyMV  = '0' --'Blank taken as zero'
      IF rdt.rdtIsValidQTY( @cQtyMV, 1) = 0 
      BEGIN      
         SET @nErrNo = 71978       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty      
         GOTO Step_3_Fail          
      END      
      
      SET @nQtyMV = CAST(@cQtyMV AS INT)

      IF @nQtyMV > @nQtyAvl 
      BEGIN
         SET @nErrNo = 71979
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYMV > QTYAVL
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_3_Fail  
      END
      
      IF @nQtyMV < 0
      BEGIN
         SET @nErrNo = 71980
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_3_Fail  
      END
        
      --prepare next screen variable
      SET @cOutField01 = @cFromCarton
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cPackUOM03
      SET @cOutField04 = @nQtyMV
      SET @cOutField05 = ''

      SET @nScn   = @nScn + 1
      SET @nStep  = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      
     SET @cOutField01 = @cFromCarton
     SET @cOutField02 = ''

     SET @nScn = @nScn - 1
     SET @nStep = @nStep - 1
     
   END
   GOTO Quit
   
   Step_3_Fail:
   BEGIN
     SET @cOutField01 = @cFromCarton
     SET @cOutField02 = @cSKU
     SET @cOutField03 = @cPackUOM03
     SET @cOutField04 = @nQtyAvl
     SET @cOutField05 = ''
   END
   
END
GOTO Quit

/********************************************************************************
Step 4. screen = 1063 
  FROM Tote (Field01)
  SKU       (Field02)
  UOM       (Field03)
  QTY MV    (Field04)
  TO Tote   (Field05, Input)   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
      SET @cToCarton = @cInField05
      
      IF ISNULL(@cToCarton,'') = ''
      BEGIN
         SET @nErrNo = 71981
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToCarton Req
         GOTO Step_4_Fail  
      END

      IF @cToCarton = @cFromCarton 
      BEGIN
         SET @nErrNo = 71982
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same Carton
         GOTO Step_4_Fail  
      END
		
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND DropID = @cToCarton)
      BEGIN
      	SET @nErrNo = 71983
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TO CARTON
         GOTO Step_4_Fail  
   	END

      -- EXECUTE CONFIRM MOVE (Start) --
      EXEC rdt.rdt_Carton_Consolidation_Confirm 
         @nMobile          ,
         @nFunc            ,
         @cStorerKey       ,   
         @cPickSlipNo      ,
         @cFromCarton      ,
         @cToCarton        ,
         @cLangCode        ,
         @cUserName        ,
         @cOption          ,
         @cSKU             ,
         @cFacility        ,
         @nQtyMV           ,
         @nErrNo           OUTPUT ,  
         @cErrMsg          OUTPUT
         
      IF @nErrNo <> 0 
      BEGIN
         SET @nErrNo = @nErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         GOTO Step_4_Fail  
      END
      -- EXECUTE CONFIRM MOVE (End) --
         
      --prepare next screen variable
      SET @nScn   = @nScn + 2
      SET @nStep  = @nStep + 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      
     SET @cOutField01 = @cFromCarton
     SET @cOutField02 = @cSKU
     SET @cOutField03 = @cPackUOM03
     SET @cOutField04 = @nQtyAvl
     SET @cOutField05 = ''

     SET @nScn = @nScn - 1
     SET @nStep = @nStep - 1
     
   END
   GOTO Quit
   
   Step_4_Fail:
   BEGIN
      SET @cOutField01 = @cFromCarton
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cPackUOM03
      SET @cOutField04 = @nQtyMV
      SET @cOutField05 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 5. screen = 1064 
  FROM Tote (Field01)
  TO Carton   (Field02, Input)   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
      SET @cToCarton = @cInField02
      
      IF ISNULL(@cToCarton,'') = ''
      BEGIN
         SET @nErrNo = 71984
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToTote Req
         GOTO Step_5_Fail  
      END

      IF @cToCarton = @cFromCarton 
      BEGIN
         SET @nErrNo = 71985
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same Carton
         GOTO Step_5_Fail  
      END
		
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND DropID = @cToCarton)
      BEGIN
      	SET @nErrNo = 71986
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TO CARTON
         GOTO Step_5_Fail  
   	END

      -- EXECUTE CONFIRM MOVE (Start) --
      EXEC rdt.rdt_Carton_Consolidation_Confirm 
         @nMobile         ,   
         @nFunc            ,
         @cStorerKey      ,   
         @cPickSlipNo     ,
         @cFromCarton     ,
         @cToCarton       ,
         @cLangCode       ,
         @cUserName       ,
         @cOption         ,
         ''               ,   -- SKU (no need here as it is whole tote) 
         @cFacility       ,
         0                ,   -- Qty to move (same as above)
         @nErrNo          OUTPUT ,  
         @cErrMsg         OUTPUT
      
      IF @nErrNo <> 0 
      BEGIN
         SET @nErrNo = @nErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         GOTO Step_5_Fail  --(james01)
      END
      -- EXECUTE CONFIRM MOVE (End) --
         
      --prepare next screen variable
      SET @nScn   = @nScn + 1
      SET @nStep  = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 1
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
   
      SET @nScn  = @nPrevScn 
      SET @nStep = @nPrevStep
   END
   GOTO Quit
   
   Step_5_Fail:
   BEGIN
      SET @cOutField01 = @cFromCarton
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 1065 
   Message
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey IN (1, 0)   -- ENTER / ESC
   BEGIN
      IF @cOption = 'F'
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 1
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
   
         SET @nScn  = @nScn - 5 
         SET @nStep = @nStep - 5
      END
      ELSE
      BEGIN
        SET @cOutField01 = @cFromCarton
        SET @cOutField02 = ''

        SET @nScn = @nScn - 4
        SET @nStep = @nStep - 4
      END
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
      -- UserName      = @cUserName,
        
      V_SKU              = @cSKU,          
      V_UOM              = @cPackUOM03,
   
      V_String1      = @cPickSlipNo,
      V_String2      = @cFromCarton,
      V_String3      = @cPackkey,
      V_String6      = @cToCarton,
      V_String7      = @cOption,
      
      V_Integer1     = @nQtyAvl,
      V_Integer2     = @nQtyMV,
      
      V_FromStep     = @nPrevStep,
      V_FromScn      = @nPrevScn,

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
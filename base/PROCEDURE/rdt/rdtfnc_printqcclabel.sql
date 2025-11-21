SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PrintQCCLabel                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: QCC Label Printing by outbound UCC                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 16-05-2014  1.0  James    SOS310288 - Created (james01)              */
/* 02-09-2014  1.1  Ung      SOS310288 Clean up source                  */
/* 04-08-2015  1.2  Audrey   SOS349587 - Add Isnull              (ang01)*/
/* 30-09-2016  1.3  Ung      Performance tuning                         */
/* 08-11-2018  1.4  TungGH   Performance                                */  
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_PrintQCCLabel] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- Other var use in this stor proc
DECLARE 
   @b_Success         INT, 
   @n_err             INT, 
   @c_errmsg          NVARCHAR( 250), 
   @c_outstring       NVARCHAR( 255)

DECLARE 
   @nFunc               INT,    
   @nScn                INT,    
   @nCurScn             INT,  -- Current screen variable    
   @nStep               INT,    
   @nCurStep            INT,    
   @cLangCode           NVARCHAR( 3),    
   @nInputKey           INT,    
   @nMenu               INT,    

   @cStorerkey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),    
   @cUserName           NVARCHAR( 18),    
   @cPUOM               NVARCHAR( 10),    
   
   @cUCCNo              NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cLottable01         NVARCHAR( 18),
   @cType               NVARCHAR( 10),
   @nQty                INT, 
   @nLottable01_Cnt     INT, 
   @bSuccess            INT, 
   @nSeq                INT, 

   @cQty1 NVARCHAR( 5),       @cQty2 NVARCHAR( 5), 
   @cQty3 NVARCHAR( 5),       @cQty4 NVARCHAR( 5), 
   @cQty5 NVARCHAR( 5),    

   @cTtl_Qty1 NVARCHAR( 5),   @cTtl_Qty2 NVARCHAR( 5), 
   @cTtl_Qty3 NVARCHAR( 5),   @cTtl_Qty4 NVARCHAR( 5), 
   @cTtl_Qty5 NVARCHAR( 5),   @cTtl_Qty  NVARCHAR( 5), 

   @nQty1 INT,                @nQty2 INT, 
   @nQty3 INT,                @nQty4 INT, 
   @nQty5 INT,    


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
   @cFieldAttr15 NVARCHAR( 1),  
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20) 
 

-- Getting Mobile information
SELECT 
   @nFunc      = Func,    
   @nScn       = Scn,    
   @nStep      = Step,    
   @nInputKey  = InputKey,    
   @nMenu      = Menu,    
   @cLangCode  = Lang_code,    
    
   @cStorerkey = StorerKey,    
   @cFacility  = Facility,    
   @cPrinter   = Printer,    
   @cUserName  = UserName,    
    
   @cUCCNo        = V_UCC, 
   @cSKU          = V_SKU,

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

FROM RDT.RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    

IF @nFunc = 594 -- Print QCC Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 594. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 3850. UCC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 3851. COO, PRINT, TTL
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 521. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- (Vicky06) EventLog - Sign In Function    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign in function    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerkey  = @cStorerkey,
      @nStep       = @nStep   
    
   -- reset all output    
   SET @cUCCNo = ''    
    
   -- Init screen    
   SET @cOutField01 = '' -- UCC 
   
   -- Set the entry point
   SET @nScn = 3850
   SET @nStep = 1

   -- Reset field attribute
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

/********************************************************************************
Step 1. Scn = 3850
   UCC         (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField01 

      -- Check blank
      IF @cUCCNo = ''
      BEGIN
         SET @nErrNo = 88351 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UCC req' 
         GOTO Step_1_Fail
      END

      -- Check label packed
      IF NOT EXISTS( SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Labelno = @cUCCNo)
      BEGIN
         SET @nErrNo = 88352 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID UCC'
         GOTO Step_1_Fail
      END

      -- Get Order info
      DECLARE @cOrderKey NVARCHAR(10)
      DECLARE @cOrderStatus NVARCHAR(10)
      DECLARE @cRefNo NVARCHAR(20)
      SELECT 
         @cOrderKey = O.OrderKey, 
         @cOrderStatus = O.Status, 
         @cRefNo = RefNo
      FROM dbo.PackHeader PH WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey) 
      WHERE O.StorerKey = @cStorerKey
         AND PD.Labelno = @cUCCNo

      -- Check order shipped
      IF @cOrderStatus = '9'
      BEGIN
         SET @nErrNo = 88357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ORDER SHIPPED'
         GOTO Step_1_Fail
      END

      -- Check order cancel
      IF @cOrderStatus = 'CANC'
      BEGIN
         SET @nErrNo = 88358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ORDER CANCEL'
         GOTO Step_1_Fail
      END

      -- Print for FCP (UCC, 1 SKU)
      IF EXISTS( SELECT TOP 1 1 
         FROM PackDetail PD WITH (NOLOCK)
            JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.RefNo AND PD.RefNo <> '')
         WHERE UCC.StorerKey = @cStorerKey
            AND PD.LabelNo = @cUCCNo)
      BEGIN
         -- Get UCC info
         SELECT 
            @cSKU = UCC.SKU,
            @nQTY = UCC.QTY, 
            @cLottable01 = LA.Lottable01
         FROM UCC WITH (NOLOCK)
            JOIN LotAttribute LA WITH (NOLOCK) ON (UCC.LOT = LA.LOT)
         WHERE UCC.StorerKey = @cStorerKey
            AND UCC.UCCNo = @cRefNo

         -- Print label
         EXEC rdt.rdt_PrintQCCLabel 
             @nMobile
            ,@nFunc  
            ,@cLangCode
            ,@cStorerKey
            ,@cUCCNo    
            ,@cSKU      
            ,@cLottable01
            ,@nQTY
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT   
         IF @nErrNo <> 0
            GOTO Step_1_Fail
      
         SET @cOutField01 = ''
         GOTO Quit
      END

      DECLARE @tLabel TABLE
      (
         SKU NVARCHAR(20), 
         QTY INT, 
         L01Cnt INT
      )

      -- Get info for non-FCP (loose pack carton, 1 or more SKU)
      INSERT INTO @tLabel (SKU, QTY, L01Cnt)
      SELECT 
         PAD.SKU, PAD.QTY, 
         (
            SELECT COUNT( DISTINCT LA.Lottable01)
            FROM PickDetail PID WITH (NOLOCK)
               JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PID.LOT)
            WHERE PID.OrderKey = @cOrderKey
               AND PID.StorerKey = @cStorerKey -- For utilize index 
               AND PID.SKU = PAD.SKU
               AND ISNULL(PID.CartonType,'') <> 'FCP' --ang01  
               AND PID.QTY > 0
               AND PID.Status <> '4' -- Short
         ) L01Cnt
      FROM PackDetail PAD WITH (NOLOCK)
      WHERE PAD.StorerKey = @cStorerKey
         AND PAD.LabelNo = @cUCCNo

      -- Print for SKU with only 1 Lottable01
      IF EXISTS( SELECT TOP 1 1 FROM @tLabel WHERE L01Cnt = 1)
      BEGIN
         DECLARE @curLabel CURSOR
         SET @curLabel = CURSOR SCROLL FOR 
            SELECT SKU, QTY FROM @tLabel WHERE L01Cnt = 1
         OPEN @curLabel
         FETCH NEXT FROM @curLabel INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get Lottable01
            SELECT @cLottable01 = LA.Lottable01
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey -- For utilize index 
               AND PD.SKU = @cSKU
               AND ISNULL(PD.CartonType,'') <> 'FCP'--ang01  
               AND PD.QTY > 0
               AND PD.Status <> '4' -- Short
            
            -- Print label
            EXEC rdt.rdt_PrintQCCLabel 
                @nMobile
               ,@nFunc  
               ,@cLangCode
               ,@cStorerKey
               ,@cUCCNo    
               ,@cSKU      
               ,@cLottable01
               ,@nQTY
               ,@nErrNo          OUTPUT
               ,@cErrMsg         OUTPUT   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
            
            FETCH NEXT FROM @curLabel INTO @cSKU, @nQTY
         END
      END

      -- Go to next screen for SKU with more then 1 Lottable01
      IF EXISTS( SELECT TOP 1 1 FROM @tLabel WHERE L01Cnt > 1)
      BEGIN
         SET @cSKU = ''
         SET @cType = ''
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PrintQCC_GetStat] 
             @nMobile
            ,@nFunc
            ,@cLangCode
            ,@cStorerKey
            ,@cUCCNo
            ,@cType
            ,@cSKU            OUTPUT
            ,@c_oFieled01     OUTPUT
            ,@c_oFieled02     OUTPUT
            ,@c_oFieled03     OUTPUT
            ,@c_oFieled04     OUTPUT
            ,@c_oFieled05     OUTPUT
            ,@c_oFieled06     OUTPUT
            ,@c_oFieled07     OUTPUT
            ,@c_oFieled08     OUTPUT
            ,@c_oFieled09     OUTPUT
            ,@c_oFieled10     OUTPUT
            ,@c_oFieled11     OUTPUT
            ,@c_oFieled12     OUTPUT
            ,@c_oFieled13     OUTPUT
            ,@c_oFieled14     OUTPUT
            ,@c_oFieled15     OUTPUT 
            ,@bSuccess        OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT   

         SET @cOutField01 = @cUCCNo
         SET @cOutField02 = @cSKU
         -- Lottable01
         SET @cOutField03 = @c_oFieled03 + SPACE(9 - LEN(RTRIM(@c_oFieled03))) + @c_oFieled08
         SET @cOutField04 = @c_oFieled04 + SPACE(9 - LEN(RTRIM(@c_oFieled04))) + @c_oFieled09
         SET @cOutField05 = @c_oFieled05 + SPACE(9 - LEN(RTRIM(@c_oFieled05))) + @c_oFieled10
         SET @cOutField06 = @c_oFieled06 + SPACE(9 - LEN(RTRIM(@c_oFieled06))) + @c_oFieled11
         SET @cOutField07 = @c_oFieled07 + SPACE(9 - LEN(RTRIM(@c_oFieled07))) + @c_oFieled12

         -- Ttl qty for each lottable
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         
         SET @cFieldAttr08 = CASE WHEN ISNULL( @c_oFieled03, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr09 = CASE WHEN ISNULL( @c_oFieled04, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN ISNULL( @c_oFieled05, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr11 = CASE WHEN ISNULL( @c_oFieled06, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr12 = CASE WHEN ISNULL( @c_oFieled07, '') = '' THEN 'O' ELSE '' END

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function    
     EXEC RDT.rdt_STD_EventLog    
       @cActionType = '9', -- Sign Out function    
       @cUserID     = @cUserName,    
       @nMobileNo   = @nMobile,    
       @nFunctionID = @nFunc,    
       @cFacility   = @cFacility,    
       @cStorerkey  = @cStorerkey,
       @nStep       = @nStep  

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset field attribute
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
      SET @cOutField01 = ''
      SET @cUCCNo = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 927
   UCC            (field01)
   Suggested LOC  (field02)
   To LOC         (field03, input)
********************************************************************************/
Step_2:
BEGIN
 IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cUCCNo = @cOutField01
      SET @cSKU = @cOutField02
      
      -- Screen mapping
      SET @cQty1 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE '0' END
      SET @cQty2 = CASE WHEN @cFieldAttr09 = '' THEN @cInField09 ELSE '0' END
      SET @cQty3 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE '0' END
      SET @cQty4 = CASE WHEN @cFieldAttr11 = '' THEN @cInField11 ELSE '0' END
      SET @cQty5 = CASE WHEN @cFieldAttr12 = '' THEN @cInField12 ELSE '0' END

      IF (@cFieldAttr08 = '' AND @cInField08 <> '' AND RDT.rdtIsValidQTY( @cQty1, 1) = 0) OR 
         (@cFieldAttr09 = '' AND @cInField09 <> '' AND RDT.rdtIsValidQTY( @cQty2, 1) = 0) OR
         (@cFieldAttr10 = '' AND @cInField10 <> '' AND RDT.rdtIsValidQTY( @cQty3, 1) = 0) OR
         (@cFieldAttr11 = '' AND @cInField11 <> '' AND RDT.rdtIsValidQTY( @cQty4, 1) = 0) OR
         (@cFieldAttr12 = '' AND @cInField12 <> '' AND RDT.rdtIsValidQTY( @cQty5, 1) = 0) 
      BEGIN
         SET @nErrNo = 88353 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID QTY' 
         GOTO Step_2_Fail             
      END 

--      INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES 
--      ('QCC', GETDATE(), @cQty1, @cQty2, @cQty3, @cQty4, @cQty5)
      IF (@cQty1 = '0' OR @cQty1 = '') AND 
         (@cQty2 = '0' OR @cQty2 = '') AND 
         (@cQty3 = '0' OR @cQty3 = '') AND 
         (@cQty4 = '0' OR @cQty4 = '') AND 
         (@cQty5 = '0' OR @cQty5 = '') 
      BEGIN
         -- User leave blank to get next SKU
         SET @cType = 'NEXT'
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PrintQCC_GetStat] 
             @nMobile
            ,@nFunc
            ,@cLangCode
            ,@cStorerKey
            ,@cUCCNo
            ,@cType
            ,@cSKU            OUTPUT
	         ,@c_oFieled01     OUTPUT
	         ,@c_oFieled02     OUTPUT
            ,@c_oFieled03     OUTPUT
            ,@c_oFieled04     OUTPUT
            ,@c_oFieled05     OUTPUT
            ,@c_oFieled06     OUTPUT
            ,@c_oFieled07     OUTPUT
            ,@c_oFieled08     OUTPUT
            ,@c_oFieled09     OUTPUT
            ,@c_oFieled10     OUTPUT
	         ,@c_oFieled11     OUTPUT
	         ,@c_oFieled12     OUTPUT
            ,@c_oFieled13     OUTPUT
            ,@c_oFieled14     OUTPUT
            ,@c_oFieled15     OUTPUT 
            ,@bSuccess        OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT   

         IF ISNULL( @cSKU, '') = ''
         BEGIN
--            SET @nErrNo = 88355 
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO MORE REC' 
--            GOTO Step_2_Fail             
            -- Prepare prev screen variable  
            SET @cOutField01 = ''  
            SET @cUCCNo = ''  
        
            -- Go to prev screen  
            SET @nScn  = @nScn  - 1  
            SET @nStep = @nStep - 1  

            -- Reset field attribute
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
            
            GOTO Quit
         END 
      
         SET @cOutField01 = @cUCCNo
         SET @cOutField02 = @cSKU
         -- Lottable01
         SET @cOutField03 = @c_oFieled03 + SPACE(9 - LEN(RTRIM(@c_oFieled03))) + @c_oFieled08
         SET @cOutField04 = @c_oFieled04 + SPACE(9 - LEN(RTRIM(@c_oFieled04))) + @c_oFieled09
         SET @cOutField05 = @c_oFieled05 + SPACE(9 - LEN(RTRIM(@c_oFieled05))) + @c_oFieled10
         SET @cOutField06 = @c_oFieled06 + SPACE(9 - LEN(RTRIM(@c_oFieled06))) + @c_oFieled11
         SET @cOutField07 = @c_oFieled07 + SPACE(9 - LEN(RTRIM(@c_oFieled07))) + @c_oFieled12

         -- Ttl qty for each lottable
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         
         SET @cFieldAttr08 = CASE WHEN ISNULL( @c_oFieled03, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr09 = CASE WHEN ISNULL( @c_oFieled04, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN ISNULL( @c_oFieled05, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr11 = CASE WHEN ISNULL( @c_oFieled06, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr12 = CASE WHEN ISNULL( @c_oFieled07, '') = '' THEN 'O' ELSE '' END
         
         GOTO Quit
      END

      SET @cTtl_Qty = CASE WHEN @cFieldAttr08 = '' THEN RIGHT( @cOutField03, 4) ELSE '0' END
--      SET @cTtl_Qty1 = CASE WHEN @cFieldAttr08 = '' THEN RIGHT( @cOutField03, 4) ELSE '0' END
--      SET @cTtl_Qty2 = CASE WHEN @cFieldAttr09 = '' THEN RIGHT( @cOutField04, 4) ELSE '0' END
--      SET @cTtl_Qty3 = CASE WHEN @cFieldAttr10 = '' THEN RIGHT( @cOutField05, 4) ELSE '0' END
--      SET @cTtl_Qty4 = CASE WHEN @cFieldAttr11 = '' THEN RIGHT( @cOutField06, 4) ELSE '0' END
--      SET @cTtl_Qty5 = CASE WHEN @cFieldAttr12 = '' THEN RIGHT( @cOutField07, 4) ELSE '0' END


      
      IF ( CAST( @cQty1 AS INT) > CAST( @cTtl_Qty1 AS INT)) OR 
         ( CAST( @cQty2 AS INT) > CAST( @cTtl_Qty2 AS INT)) OR 
         ( CAST( @cQty3 AS INT) > CAST( @cTtl_Qty3 AS INT)) OR 
         ( CAST( @cQty4 AS INT) > CAST( @cTtl_Qty4 AS INT)) OR 
         ( CAST( @cQty5 AS INT) > CAST( @cTtl_Qty5 AS INT)) 
      BEGIN
         SET @nErrNo = 88354 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PRT QTY>TTL' 
         GOTO Step_2_Fail             
      END 

      IF ( CAST( @cQty1 AS INT) + CAST( @cQty2 AS INT) + CAST( @cQty3 AS INT) + CAST( @cQty4 AS INT) + CAST( @cQty5 AS INT)) > 
          CAST( @cTtl_Qty AS INT)
      BEGIN
         SET @nErrNo = 88356 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PRT QTY>TTL' 
         GOTO Step_2_Fail             
      END 

      SET @nQty1 = CAST( @cQty1 AS INT)
      SET @nQty2 = CAST( @cQty2 AS INT)
      SET @nQty3 = CAST( @cQty3 AS INT)
      SET @nQty4 = CAST( @cQty4 AS INT)
      SET @nQty5 = CAST( @cQty5 AS INT)

      DECLARE @tPrint TABLE (Seq INT, LOT01 NVARCHAR( 18), QTY INT)
      INSERT INTO @tPrint (Seq, LOT01, QTY) VALUES (1, CASE WHEN @nQty1 > 0 THEN SUBSTRING( @cOutField03, 1, 9) ELSE '' END, @nQty1)
      INSERT INTO @tPrint (Seq, LOT01, QTY) VALUES (2, CASE WHEN @nQty2 > 0 THEN SUBSTRING( @cOutField04, 1, 9) ELSE '' END, @nQty2)
      INSERT INTO @tPrint (Seq, LOT01, QTY) VALUES (3, CASE WHEN @nQty3 > 0 THEN SUBSTRING( @cOutField05, 1, 9) ELSE '' END, @nQty3)
      INSERT INTO @tPrint (Seq, LOT01, QTY) VALUES (4, CASE WHEN @nQty4 > 0 THEN SUBSTRING( @cOutField06, 1, 9) ELSE '' END, @nQty4)
      INSERT INTO @tPrint (Seq, LOT01, QTY) VALUES (5, CASE WHEN @nQty5 > 0 THEN SUBSTRING( @cOutField07, 1, 9) ELSE '' END, @nQty5)

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT Seq, LOT01, QTY FROM @tPrint 
      WHERE LOT01 <> '' AND Qty > 0 
      ORDER BY Seq
      OPEN CUR_LOOP 
      FETCH NEXT FROM CUR_LOOP INTO @nSeq, @cLottable01, @nQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Print sku with single lot first
         SET @nErrNo = 0
         EXEC rdt.rdt_PrintQCCLabel 
             @nMobile
            ,@nFunc  
            ,@cLangCode
            ,@cStorerKey
            ,@cUCCNo    
            ,@cSKU      
            ,@cLottable01     -- Lottable01
            ,@nQty            -- Qty
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT   

         IF @nErrNo <> 0
         BEGIN
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            GOTO Step_2_Fail
         END

         FETCH NEXT FROM CUR_LOOP INTO @nSeq, @cLottable01, @nQty
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      -- After printing try get next SKU
      SET @cType = 'NEXT'
      SET @nErrNo = 0
      EXEC [RDT].[rdt_PrintQCC_GetStat] 
          @nMobile
         ,@nFunc
         ,@cLangCode
         ,@cStorerKey
         ,@cUCCNo
         ,@cType
         ,@cSKU            OUTPUT
         ,@c_oFieled01     OUTPUT
         ,@c_oFieled02     OUTPUT
         ,@c_oFieled03     OUTPUT
         ,@c_oFieled04     OUTPUT
         ,@c_oFieled05     OUTPUT
         ,@c_oFieled06     OUTPUT
         ,@c_oFieled07     OUTPUT
         ,@c_oFieled08     OUTPUT
         ,@c_oFieled09     OUTPUT
         ,@c_oFieled10     OUTPUT
         ,@c_oFieled11     OUTPUT
         ,@c_oFieled12     OUTPUT
         ,@c_oFieled13     OUTPUT
         ,@c_oFieled14     OUTPUT
         ,@c_oFieled15     OUTPUT 
         ,@bSuccess        OUTPUT
         ,@nErrNo          OUTPUT
         ,@cErrMsg         OUTPUT   

      IF ISNULL( @cSKU, '') = ''
      BEGIN
         -- Prepare prev screen variable  
         SET @cOutField01 = ''  
         SET @cUCCNo = ''  
     
         -- Go to prev screen  
         SET @nScn  = @nScn  - 1  
         SET @nStep = @nStep - 1  

         -- Reset field attribute
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
         
         GOTO Quit
      END 

      SET @cOutField01 = @cUCCNo
      SET @cOutField02 = @cSKU
      -- Lottable01
      SET @cOutField03 = @c_oFieled03 + SPACE(9 - LEN(RTRIM(@c_oFieled03))) + @c_oFieled08
      SET @cOutField04 = @c_oFieled04 + SPACE(9 - LEN(RTRIM(@c_oFieled04))) + @c_oFieled09
      SET @cOutField05 = @c_oFieled05 + SPACE(9 - LEN(RTRIM(@c_oFieled05))) + @c_oFieled10
      SET @cOutField06 = @c_oFieled06 + SPACE(9 - LEN(RTRIM(@c_oFieled06))) + @c_oFieled11
      SET @cOutField07 = @c_oFieled07 + SPACE(9 - LEN(RTRIM(@c_oFieled07))) + @c_oFieled12

      -- Ttl qty for each lottable
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      
      SET @cFieldAttr08 = CASE WHEN ISNULL( @c_oFieled03, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr09 = CASE WHEN ISNULL( @c_oFieled04, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN ISNULL( @c_oFieled05, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr11 = CASE WHEN ISNULL( @c_oFieled06, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr12 = CASE WHEN ISNULL( @c_oFieled07, '') = '' THEN 'O' ELSE '' END
      
      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen variable  
      SET @cOutField01 = ''  
      SET @cUCCNo = ''  
  
      -- Go to prev screen  
      SET @nScn  = @nScn  - 1  
      SET @nStep = @nStep - 1  

      -- Reset field attribute
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

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cUCCNo
      SET @cOutField02 = @cSKU
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,    
      Func = @nFunc,    
      Step = @nStep,    
      Scn = @nScn,    

      StorerKey   = @cStorerkey,    
      Facility    = @cFacility,    
      -- UserName    = @cUserName,    
      Printer     = @cPrinter,    
    
      V_UCC       = @cUCCNo,   
      V_SKU       = @cSKU, 

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
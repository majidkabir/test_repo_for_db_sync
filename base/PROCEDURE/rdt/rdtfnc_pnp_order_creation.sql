SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PnP_Order_Creation                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and Pack (Order Creation) (SOS284891)                  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 05-Aug-2013 1.0  James    Created                                    */
/* 02-Apr-2014 1.1  James    SOS307345 - Add customise SP (james01)     */
/* 30-Sep-2016 1.2  Ung      Performance tuning                         */
/* 09-Nov-2018 1.3  TungGH   Performance                                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PnP_Order_Creation] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success       INT,
   @n_err           INT,
   @c_errmsg        NVARCHAR(250),
   @nSKUCnt         INT

DECLARE
   @cSQL          NVARCHAR(1000),     
   @cSQLParam     NVARCHAR(1000)    
   
-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),
   @cLOC                NVARCHAR( 10),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),

   @cOrderKey           NVARCHAR( 10),
   @cOrderLineNo        NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10) ,
   @cLoadKey            NVARCHAR( 10),    
   @cTempSKU            NVARCHAR( 20), 
   @cQty                NVARCHAR( 5), 
   @cErrMsg1            NVARCHAR( 20),         
   @cErrMsg2            NVARCHAR( 20),         
   @cErrMsg3            NVARCHAR( 20),         
   @cErrMsg4            NVARCHAR( 20),         
   @cErrMsg5            NVARCHAR( 20),  
   @cPickSlipNo         NVARCHAR( 10),  
   @cOption             NVARCHAR( 1),  
   @cStore              NVARCHAR( 15),  
   @cLabelNo            NVARCHAR( 20),  
   @cDOID               NVARCHAR( 20),  
   @cSUSR1              NVARCHAR( 20),  
   @cSectionKey         NVARCHAR( 10),  
   @cCartonType         NVARCHAR( 10),  
   @cDefaultCartonType  NVARCHAR( 10),  
   @cTempQty            NVARCHAR( 5),  
   @cBUSR10             NVARCHAR( 30),  
   @cLabelNo2Cfm        NVARCHAR( 20),  
   @cPickSlipNo2Cfm     NVARCHAR( 10),  
   @cPickSlipStatus     NVARCHAR( 10),  
   @cLabelNoChkSP       NVARCHAR( 20),  
   @cExterOrderKey      NVARCHAR( 20),  
   @cPickcfm_Orders     NVARCHAR( 10),  
   @cPickcfm_PDKey      NVARCHAR( 10),  
   @cDefaultQty         NVARCHAR( 5),  
   @cLots_SKU           NVARCHAR( 20),  
   @cDefaultAllocLOC    NVARCHAR( 10),
   @nQty                INT,
   @nTtl_Qty            INT,
   @nUpdQty             INT,
   @nTranCount          INT, 
   @nByPCS              INT, 
   @nByLOTS             INT, 
   @nCNT_BuyerPO        INT, 
   @nCartonNo           INT, 
   @bSuccess            INT, 
   @nQtyAvail           INT, 
   @nDefaultQty         INT,
   @nTtl_LotsQty        INT, 
   @nLots_QTY           INT, 
   @nSKU_Count          INT, 
   @nSum_PickedQty      INT, 
   @nSum_PackedQty      INT, 

   @cPnPOrderCreation_SP   NVARCHAR( 20), -- (james01)

   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1)
   -- (Vicky02) - End

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @cPrinter         = Printer,


   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cOrderKey        = V_OrderKey, 
   @cPickSlipNo      = V_PickSlipNo, 
   @cSKU             = V_SKU,
   @nQty             = V_QTY, 
   @cStore           = V_ConsigneeKey,

   @nByPCS           = V_Integer1,
   @nByLOTS          = V_Integer2,
   @nDefaultQty      = V_Integer3,
         
   @cLabelNo         = V_String3,
   @cCartonType      = V_String4,
   @cDOID            = V_String5,
   @cSectionKey      = V_String7,   -- (james01)
   
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

   -- (Vicky02) - Start
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1798
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0    -- Menu. Func = 1798
   IF @nStep = 1  GOTO Step_1    -- Scn = 3610. Option
   IF @nStep = 2  GOTO Step_2    -- Scn = 3611. Store, By PCS/LOTS, Option
   IF @nStep = 3  GOTO Step_3    -- Scn = 3612. Store, By PCS/LOTS, Label No
   IF @nStep = 4  GOTO Step_4    -- Scn = 3613. Store, By PCS/LOTS, Carton Type
   IF @nStep = 5  GOTO Step_5    -- Scn = 3614. Store, By PCS/LOTS, SKU, QTY, Ctn Qty, UxL
   IF @nStep = 6  GOTO Step_6    -- Scn = 3615. Label No
   IF @nStep = 7  GOTO Step_7    -- Scn = 3616. Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1798. Screen 0.
********************************************************************************/
Step_0:
BEGIN
   -- (Vicky02) - Start
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
   -- (Vicky02) - End

   SET @cDefaultQty = ''
   SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF ISNULL(@cDefaultQty, '') = '' OR @cDefaultQty = '0'
      SET @nDefaultQty = 0
   ELSE
      SET @nDefaultQty = CAST( @cDefaultQty AS INT)
      
   -- Prev next screen var
   SET @cOption = ''
   SET @cOutField01 = ''

   SET @nScn = 3610
   SET @nStep = 1
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 3610. Screen 1.
   Order Packing 
   Pack Confirm
   Option      (field01)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01   

      -- Validate blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 81951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OPTION needed
         GOTO Step_1_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 81952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID OPTION
         GOTO Step_1_Fail
      END

      -- Order packing
      IF @cOption = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''   -- BY STORE
         SET @cOutField02 = ''   -- BY PCS/BY LOT

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         EXEC rdt.rdtSetFocusField @nMobile, 1
      END

      -- Pack confirm
      IF @cOption = '2'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''   -- Label No

         -- Go to next screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cOption = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''
      SET @cOption = ''
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 3611. Screen 2.
   STORE          (field01)   - Input field
   BY PCS/LOT     (field02)   - Input field
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cStore = @cInField01
      SET @cOption = @cInField02

      IF ISNULL(@cStore, '') = ''
      BEGIN
         SET @nErrNo = 81953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Store needed'
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END      

      IF NOT EXISTS (SELECT 1 FROM dbo.Storer WITH (NOLOCK) 
                     WHERE StorerKey = 'ITX' + @cStore
                     AND   Type = 2)
      BEGIN
         SET @nErrNo = 81954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID Store'
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END      
      
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @cOutField01 = @cStore
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      
      IF ISNULL(@cOption, '') <> ''
      BEGIN
         IF @cOption NOT IN ('1', '2')
         BEGIN
            SET @nErrNo = 81964
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID OPTION
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
         
         IF @cOption = '1'
         BEGIN
            SET @nByPCS = 1
            SET @nByLOTS = 0
         END
         ELSE
         BEGIN
            SET @nByPCS = 0
            SET @nByLOTS = 1
         END
         
      END

      -- Prepare next screen var
      SET @cOutField01 = @cStore   
      SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
      SET @cOutField03 = ''   -- LABEL NO

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''
      SET @cOption = ''
      
      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit

/************************************************************************************
Step_3. Scn = 3612. Screen 3.
   STORE          (field01)
   BY PCS/LOTS    (field01)
   LABEL NO       (field01)   - input field
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cLabelNo = @cInField03

      IF ISNULL(@cLabelNo, '') = ''
      BEGIN
         SET @nErrNo = 81955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LabelNo needed'
         GOTO Step_3_Fail
      END            
/*
      -- Label no validation
      -- The 1st 4 digits of labelno compare with the brand information(storer.susr1).
      -- The next 4 digits of labelno compare with the store information(right('0000'+ rtrim(Screen2.store),4)).
      -- The next 1 digits of labelno is section information.

      SELECT @cSUSR1 = ISNULL(SUSR1, '') 
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
   
      IF SUBSTRING( @cLabelNo, 1, 4) <> @cSUSR1 OR 
         SUBSTRING( @cLabelNo, 5, 4) <> RIGHT( '0000' + REPLACE( @cStore, 'ITX', ''), 4)   
      BEGIN  
         SET @nErrNo = 81956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LabelNo
         GOTO Step_3_Fail
      END  
      */
      SET @cSectionKey = SUBSTRING( @cLabelNo, 9, 1)

      SET @cLabelNoChkSP = rdt.RDTGetConfig( @nFunc, 'LabelNoChkSP', @cStorerKey)    
      IF @cLabelNoChkSP = '0'    
         SET @cLabelNoChkSP = ''    
      
      -- LabelNo extended validation    
      IF @cLabelNoChkSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cLabelNoChkSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC ' + RTRIM( @cLabelNoChkSP) +     
               ' @nMobile, @nFunc, @cLangCode, @cLoadKey, @cConsigneeKey, @cStorerKey, @cSKU, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile       INT,        ' +    
               '@nFunc         INT,        ' +    
               '@cLangCode     NVARCHAR( 3),   ' +    
               '@cLoadKey      NVARCHAR( 10),  ' +    
               '@cConsigneeKey NVARCHAR( 15),  ' +    
               '@cStorerKey    NVARCHAR( 15),  ' +    
               '@cSKU          NVARCHAR( 20),  ' +    
               '@cLabelNo      NVARCHAR( 20),  ' +    
               '@nErrNo        INT OUTPUT, ' +      
               '@cErrMsg       NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, '', @cStore, @cStorerKey, @cSKU, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 81956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LabelNo
               GOTO Step_3_Fail
            END    
         END    
      END    
      
      --Look distribution order ID 
      SELECT @nCNT_BuyerPO = COUNT(1) 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   Status IN ('0','1','2','3','4')
      -- AND   ConsigneeKey = 'ITX' + @cStore   (no need filter consignee here
      --                                         as we just wanna find whether)
      --                                         record exists)
      
      -- no open status Distribution order ID. Put Distribution Order ID with a dummy value æITXÆ.
      IF @nCNT_BuyerPO = 0
         SET @cDOID = 'ITX'
      ELSE
      BEGIN
         SELECT @cDOID = ISNULL(MAX(BuyerPO), 0) 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   Status IN ('0','1','2','3','4')
         AND   ConsigneeKey = 'ITX' + @cStore

         -- If record not exists with consignee then look for all record
         IF @cDOID = '0'
            SELECT @cDOID = ISNULL(MAX(BuyerPO), 0) 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   Status IN ('0','1','2','3','4')

         -- find two or more open status Distribution order ID. Prompt warning. Choose the max DOID and continue process.
         IF @nCNT_BuyerPO > 1
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '> 1 OPEN STATUS'
            SET @cErrMsg2 = 'DISTRIBUTION ORDER'
            SET @cErrMsg3 = 'ID FOUND.'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 =''
               SET @cErrMsg2 =''
               SET @cErrMsg3 =''
            END
         END
      END

      SET @cPnPOrderCreation_SP = rdt.RDTGetConfig( @nFunc, 'PnPOrderCreation_SP', @cStorerKey)
      IF ISNULL(@cPnPOrderCreation_SP, '') NOT IN ('', '0')
      BEGIN
         SET @nErrNo = 0
         SET @cOrderKey = ''
         EXEC RDT.rdt_PnPOrderCreation_Wrapper
             @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_LangCode      = @cLangCode
            ,@c_SPName        = @cPnPOrderCreation_SP
            ,@c_Facility      = @cFacility
            ,@c_StorerKey     = @cStorerKey 
            ,@c_Store         = @cStore
            ,@c_SKU           = @cSKU 
            ,@n_Qty           = @nQty
            ,@c_LabelNo       = @cLabelNo
            ,@c_DOID          = @cDOID
            ,@c_Type          = 'H'
            ,@c_CartonType    = @cCartonType
            ,@c_OrderKey      = @cOrderKey   OUTPUT
            ,@c_SectionKey    = @cSectionKey OUTPUT
            ,@b_Success       = @b_Success   OUTPUT
            ,@n_ErrNo         = @nErrNo      OUTPUT
            ,@c_ErrMsg        = @cErrMsg     OUTPUT
      END
      ELSE
      BEGIN
         -- Create order header
         SET @nErrNo = 0
         SET @cOrderKey = ''
         EXEC [RDT].[rdt_PnP_Order_Creation] 
            @nMobile,
            @nFunc, 
            @cLangCode,
            @cFacility,
            @cStorerkey,
            @cStore,
            @cSKU, 
            @nQty, 
            @cLabelNo,
            @cDOID,
            'H', 
            @cCartonType, 
            @cOrderKey        OUTPUT,
            @bSuccess         OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT   
      END

      IF @nErrNo <> 0
         GOTO Step_3_Fail

      IF ISNULL(@cOrderKey, '') <> ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
      SELECT TOP 1 @nCartonNo = CartonNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo

      -- If packinfo not exists, goto next screen
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
   
         -- Prepare next screen var
         SET @cOutField01 = @cStore
         SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
         SET @cOutField03 = @cLabelNo
         SET @cOutField04 = CASE WHEN ISNULL(@cDefaultCartonType, '') <> '' THEN @cDefaultCartonType ELSE '' END
         
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cBUSR10 = ''
         SET @nTtl_Qty = 0
         SET @nTtl_LotsQty = 0
         
         SELECT @nTtl_Qty = ISNULL( SUM( QTY), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo

         IF @nTtl_Qty > 0
         BEGIN
            SELECT @nSKU_Count = COUNT( DISTINCT SKU)
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo

            SELECT @cBUSR10 = BUSR10    
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   SKU = @cSKU    
            
            IF @nByLOTS = 1 
            BEGIN
               SET @nTtl_LotsQty = 0
               -- Consignee QTY total
               DECLARE @curLotsQTY_Total CURSOR
               SET @curLotsQTY_Total = CURSOR FOR 
               SELECT PAD.SKU, ISNULL( SUM( PAD.QTY), 0) 
               FROM dbo.PackDetail PAD WITH (NOLOCK) 
               JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PAD.RefNo = PID.PickDetailKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)
               WHERE PAD.PickSlipNo = @cPickSlipNo
               AND   PAD.LabelNo = @cLabelNo
               AND   ISNULL( PAD.RefNo, '') <> ''
               AND   ISNULL( OD.UserDefine04, '') = 'M'
               GROUP BY PAD.SKU
               OPEN @curLotsQTY_Total
               FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cLots_SKU, @nLots_QTY OUTPUT
                  SET @nTtl_LotsQty = @nTtl_LotsQty + @nLots_QTY
                  FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
               END
               CLOSE @curLotsQTY_Total
               DEALLOCATE @curLotsQTY_Total
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = @cStore
         SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
         SET @cOutField03 = @cLabelNo
         SET @cOutField04 = ''   -- SKU
         SET @cOutField05 = ''   -- DESCR1
         SET @cOutField06 = ''   -- DESCR2
         SET @cOutField07 = CASE WHEN @nDefaultQty = 0 THEN '' ELSE @nDefaultQty END  -- QTY
         SET @cOutField08 = CASE WHEN @nByPCS = 1 THEN @nTtl_Qty ELSE @nTtl_LotsQty END  -- CTN QTY
         SET @cOutField09 = CASE WHEN @nSKU_Count = 1 THEN @cBUSR10 ELSE '' END  -- UxL
         EXEC rdt.rdtSetFocusField @nMobile, 4
         
         -- Go to next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = ''   -- BY STORE
      SET @cOutField02 = ''   -- BY PCS/BY LOT

      -- Go to next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = ''
      SET @cLabelNo = ''
   END
END
GOTO Quit

/************************************************************************************
Step_4. Scn = 3613. Screen 4.
   STORE          (field01)
   BY PCS/LOTS    (field02)
   LABEL NO       (field03)
   CARTON TYPE    (field04)   - input field
************************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping    
      SET @cCartonType = @cInField04    

      IF NOT EXISTS (SELECT 1 FROM Cartonization CZ WITH (NOLOCK) 
                     JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
                     WHERE CartonType = ISNULL(@cCartonType, '')
                     AND   ST.StorerKey = @cStorerKey)
      BEGIN  
         SET @nErrNo = 81957  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV CTN TYPE'  
         GOTO Step_4_Fail  
      END  

      SELECT @nTtl_Qty = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo

      IF @nTtl_Qty > 0
      BEGIN
         SELECT @nSKU_Count = COUNT( DISTINCT SKU)
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo

         SELECT @cBUSR10 = BUSR10    
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU    
         
         IF @nByLOTS = 1 
         BEGIN
            SET @nTtl_LotsQty = 0
            -- Consignee QTY total
            SET @curLotsQTY_Total = CURSOR FOR 
            SELECT PAD.SKU, ISNULL( SUM( PAD.QTY), 0) 
            FROM dbo.PackDetail PAD WITH (NOLOCK) 
            JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PAD.RefNo = PID.PickDetailKey)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)
            WHERE PAD.PickSlipNo = @cPickSlipNo
            AND   PAD.LabelNo = @cLabelNo
            AND   ISNULL( PAD.RefNo, '') <> ''
            AND   ISNULL( OD.UserDefine04, '') = 'M'
            GROUP BY PAD.SKU
            OPEN @curLotsQTY_Total
            FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cLots_SKU, @nLots_QTY OUTPUT
               SET @nTtl_LotsQty = @nTtl_LotsQty + @nLots_QTY
               FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
            END
            CLOSE @curLotsQTY_Total
            DEALLOCATE @curLotsQTY_Total
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cStore
      SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
      SET @cOutField03 = @cLabelNo
      SET @cOutField04 = ''   -- SKU
      SET @cOutField05 = ''   -- DESCR1
      SET @cOutField06 = ''   -- DESCR2
      SET @cOutField07 = CASE WHEN @nDefaultQty = 0 THEN '' ELSE @nDefaultQty END  -- QTY
      SET @cOutField08 = CASE WHEN @nByPCS = 1 THEN @nTtl_Qty ELSE @nTtl_LotsQty END  -- CTN QTY
      SET @cOutField09 = CASE WHEN @nSKU_Count = 1 THEN @cBUSR10 ELSE '' END  -- UxL
      EXEC rdt.rdtSetFocusField @nMobile, 4
      
      -- Go to QTY screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cLabelNo = ''
      SET @cOutField01 = @cStore   
      SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
      SET @cOutField03 = ''   -- LABEL NO
      
      -- Go back first screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_4_Fail:    
   BEGIN    
      SET @cCartonType = ''
      SET @cOutField04 = ''  
   END    
END
GOTO Quit

/************************************************************************************
Step_5. Scn = 3614. Screen 5.
   STORE          (field01)
   BY PCS/LOTS    (field02)
   LABEL NO       (field03)
   CARTON TYPE    (field04)   - input field
   SKU            (field05)
   DESCR          (field06)
   DESCR          (field07)
   QTY            (field06)
   CTN QTY        (field08)
   UxL            (field09)
************************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cTempSKU = @cInfield04
      SET @cTempQty = @cInfield07

      -- Check blank    
      IF ISNULL(@cTempSKU, '') = ''    
      BEGIN    
         SET @nErrNo = 81958    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU required 
         GOTO Step_5_SKU_Fail    
      END    
    
      -- Get SKU count    
      EXEC [RDT].[rdt_GETSKUCNT]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cTempSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
    
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 81959    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_5_SKU_Fail    
      END    
    
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 81960    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
         GOTO Step_5_SKU_Fail    
      END    
    
      -- Get SKU    
      EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cTempSKU      OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
    
      SET @cSKU = @cTempSKU

      -- if the section in the sku and lableno are different, prompt error
      IF NOT EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   SKU = @cSKU
                     AND   ItemClass = @cSectionKey)
                     --AND   ItemClass = SUBSTRING(@cLabelNo, 9, 1))    comment (james01)

      BEGIN    
         SET @nErrNo = 81968    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SECTION    
         GOTO Step_5_SKU_Fail    
      END    
      
      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr, 
         @cBUSR10 = BUSR10    
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU    

      -- If qty field is blank then set focus. To cater for scanned with auto enter
      IF ISNULL(@cTempQty, '') = '' OR @cTempQty = '0'
      BEGIN
         SET @cOutField04 = @cSKU
         SET @cOutField05 = SUBSTRING(@cSKUDescr, 1, 20)
         SET @cOutField06 = SUBSTRING(@cSKUDescr, 21, 20)
         SET @cOutField07 = CASE WHEN @nDefaultQty = 0 THEN '' ELSE @nDefaultQty END  -- QTY
         SET @cOutField09 = @cBUSR10
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Quit
      END
      
      VALIDATE_QTY:  
      IF @cTempQty = '0'  
      BEGIN  
         SET @nErrNo = 81961  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
         GOTO Step_5_QTY_Fail
      END  
  
      IF RDT.rdtIsValidQTY( @cTempQty, 1) = 0  
      BEGIN  
         SET @nErrNo = 81962  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
         GOTO Step_5_QTY_Fail
      END  
      
      SET @nQty = CAST( @cTempQty AS INT)

      -- Get SKU info    
      SELECT 
         @cSKUDescr = Descr, 
         @cBUSR10 = BUSR10    
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   SKU = @cSKU    
      
      IF @nByLOTS = 1
      BEGIN
         IF ISNULL( @cBUSR10, '') = '' OR ISNUMERIC( @cBUSR10) = 0
         BEGIN  
            SET @nErrNo = 81966  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid UxL'  
            GOTO Step_5_QTY_Fail
         END  
         
         SET @nQty = @nQty * CAST( @cBUSR10 AS INT)
      END

      --Default Allocation LOC
      SET @cDefaultAllocLOC = ''
      SET @cDefaultAllocLOC = rdt.RDTGetConfig( @nFunc, 'DefaultAllocLoc', @cStorerKey)

      -- Check qty available to allocate
      SELECT @nQtyAvail = ISNULL( SUM( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked), 0)
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LOC.Facility = @cFacility
      AND LOC.LOC = CASE WHEN ISNULL( @cDefaultAllocLOC, '') <> '' THEN @cDefaultAllocLOC ELSE LOC.LOC END

      IF @nQtyAvail < @nQty
      BEGIN  
         SET @nErrNo = 81967  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVAL X ENUF'  
         GOTO Step_5_QTY_Fail
      END  
         
      SET @cOutField05 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField06 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField09 = @cBUSR10

      SET @cPnPOrderCreation_SP = rdt.RDTGetConfig( @nFunc, 'PnPOrderCreation_SP', @cStorerKey)
      IF ISNULL(@cPnPOrderCreation_SP, '') NOT IN ('', '0')
      BEGIN
         EXEC RDT.rdt_PnPOrderCreation_Wrapper
             @n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_LangCode      = @cLangCode
            ,@c_SPName        = @cPnPOrderCreation_SP
            ,@c_Facility      = @cFacility
            ,@c_StorerKey     = @cStorerKey 
            ,@c_Store         = @cStore
            ,@c_SKU           = @cSKU 
            ,@n_Qty           = @nQty
            ,@c_LabelNo       = @cLabelNo
            ,@c_DOID          = @cDOID
            ,@c_Type          = 'D'
            ,@c_CartonType    = @cCartonType
            ,@c_OrderKey      = @cOrderKey   OUTPUT
            ,@c_SectionKey    = @cSectionKey OUTPUT
            ,@b_Success       = @b_Success   OUTPUT
            ,@n_ErrNo         = @nErrNo      OUTPUT
            ,@c_ErrMsg        = @cErrMsg     OUTPUT
      END
      ELSE
      BEGIN
         -- Create order header
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PnP_Order_Creation] 
            @nMobile,
            @nFunc, 
            @cLangCode,
            @cFacility,
            @cStorerkey,
            @cStore,
            @cSKU, 
            @nQty, 
            @cLabelNo,
            @cDOID,
            'D', 
            @cCartonType, 
            @cOrderKey        OUTPUT,
            @bSuccess         OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT   
      END

      IF @nErrNo <> 0
         GOTO Step_5_Fail

      IF ISNULL(@cOrderKey, '') <> ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
      SELECT @nTtl_Qty = ISNULL( SUM( QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo

      IF @nTtl_Qty > 0
      BEGIN
         SELECT @nSKU_Count = COUNT( DISTINCT SKU)
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo

         SELECT @cBUSR10 = BUSR10    
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU    
         
         IF @nByLOTS = 1 
         BEGIN
            SET @nTtl_LotsQty = 0
            -- Consignee QTY total
            SET @curLotsQTY_Total = CURSOR FOR 
            SELECT PAD.SKU, ISNULL( SUM( PAD.QTY), 0) 
            FROM dbo.PackDetail PAD WITH (NOLOCK) 
            JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PAD.RefNo = PID.PickDetailKey)
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)
            WHERE PAD.PickSlipNo = @cPickSlipNo
            AND   PAD.LabelNo = @cLabelNo
            AND   ISNULL( PAD.RefNo, '') <> ''
            AND   ISNULL( OD.UserDefine04, '') = 'M'
            GROUP BY PAD.SKU
            OPEN @curLotsQTY_Total
            FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cLots_SKU, @nLots_QTY OUTPUT
               SET @nTtl_LotsQty = @nTtl_LotsQty + @nLots_QTY
               FETCH NEXT FROM @curLotsQTY_Total INTO @cLots_SKU, @nLots_QTY
            END
            CLOSE @curLotsQTY_Total
            DEALLOCATE @curLotsQTY_Total
         END
      END
         
      -- Prepare current screen var
      SET @cOutField01 = @cStore
      SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
      SET @cOutField03 = @cLabelNo
      SET @cOutField04 = ''   -- SKU
      SET @cOutField05 = ''   -- DESCR1
      SET @cOutField06 = ''   -- DESCR2
      SET @cOutField07 = CASE WHEN @nDefaultQty = 0 THEN '' ELSE @nDefaultQty END  -- QTY
      SET @cOutField08 = CASE WHEN @nByPCS = 1 THEN @nTtl_Qty ELSE @nTtl_LotsQty END  -- CTN QTY
      SET @cOutField09 = CASE WHEN @nSKU_Count = 1 THEN @cBUSR10 ELSE '' END  -- UxL
      EXEC rdt.rdtSetFocusField @nMobile, 4

--      -- Go back label no screen
--      SET @nScn = @nScn - 2
--      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = @cStore   
      SET @cOutField02 = CASE WHEN @nByPCS = 1 THEN 'SCAN BY PCS' ELSE 'SCAN BY LOTS' END
      SET @cOutField03 = ''   -- LABEL NO

      -- Go back first screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit
   
   Step_5_Fail:
   BEGIN
      SET @cOutField04 = @cTempSKU
      SET @cOutField07 = @cTempQty
      SET @cTempSKU = ''
      SET @cTempQty = ''
      EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END
   
   Step_5_SKU_Fail:
   BEGIN
      SET @cOutField04 = ''
      SET @cTempSKU = ''
      EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END
   
   Step_5_QTY_Fail:
   BEGIN
      SET @cOutField07 = CASE WHEN @nDefaultQty = 0 THEN '' ELSE @nDefaultQty END  -- QTY
      SET @cTempQty = ''
      EXEC rdt.rdtSetFocusField @nMobile, 7
      GOTO Quit
   END
END
GOTO Quit

/************************************************************************************
Step_6. Scn = 3615. Screen 6.
   STORE          (field01)
   BY PCS/LOTS    (field02)
   LABEL NO       (field03)
   CARTON TYPE    (field04)   - input field
   SKU            (field05)
   DESCR          (field06)
   DESCR          (field07)
   QTY            (field06)
   CTN QTY        (field08)
   UxL            (field09)
************************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cLabelNo2Cfm = @cInfield01
      
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   LabelNo = @cLabelNo2Cfm)
      BEGIN    
         SET @nErrNo = 81962    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID LBL NO    
         GOTO Step_6_Fail    
      END    

      SELECT TOP 1 @cPickSlipNo2Cfm = PickSlipNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   LabelNo = @cLabelNo2Cfm

      SELECT @cPickSlipStatus = [Status] 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo2Cfm
      
      IF ISNULL(@cPickSlipStatus, '') = '9'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = 'ORDERS HAS BEEN'
         SET @cErrMsg2 = 'PACK CONFIRMED.'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2 
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 =''
            SET @cErrMsg2 =''
         END
         GOTO Step_6_Fail 
      END
      ELSE
      BEGIN
         SELECT @nSum_PickedQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE OrderKey IN (
            SELECT DISTINCT OrderKey 
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo2Cfm
            AND   Status <> '9')
         AND StorerKey = @cStorerKey
--         AND STATUS = '5'

         SELECT @nSum_PackedQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo2Cfm
         AND   StorerKey = @cStorerKey

         IF @nSum_PickedQty <> @nSum_PackedQty
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = 'QTY PICKED N PACKED'
            SET @cErrMsg2 = 'NOT MATCH.'
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = 'PACK CONFIRM FAIL.'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4 
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
            END
            GOTO Step_6_Fail 
         END
      
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
            STATUS = '9' 
         WHERE PickSlipNo = @cPickSlipNo2Cfm
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81963    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PACK CFM FAIL    
            GOTO Step_6_Fail    
         END
         ELSE
         BEGIN
            -- Scan out picking to confirm pick
            UPDATE PickingInfo WITH (ROWLOCK) SET 
               ScanOutDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo2Cfm
            AND   ISNULL(ScanOutDate, '') = ''

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81963    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PACK CFM FAIL    
               GOTO Step_6_Fail    
            END
         END
      END

      -- Go to successfully screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare next screen var
      SET @cOption = ''
      SET @cOutField01 = ''
          
      -- Go to QTY screen    
      SET @nScn  = @nScn - 5    
      SET @nStep = @nStep - 5    
   END
   GOTO Quit
   
   Step_6_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cLabelNo2Cfm = ''
      SET @cPickSlipNo2Cfm = ''
   END
END
GOTO Quit

/************************************************************************************
Step_7. Scn = 3616. Screen 7.
   MESSAGE
************************************************************************************/
Step_7:
BEGIN
   IF @nInputKey IN (0, 1) -- Yes or Send/Esc or No
   BEGIN
      -- Prev next screen var
      SET @cOption = ''
      SET @cOutField01 = ''
      
      -- Go back first screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
   END
END
GOTO Quit

/********************************************************************************
Quit. UPDATE back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      Printer        = @cPrinter,
      
      V_OrderKey     = @cOrderKey, 
      V_PickSlipNo   = @cPickSlipNo, 
   
      V_SKU          = @cSKU,
      V_QTY          = @nQty, 
      V_ConsigneeKey = @cStore,

      V_Integer1     = @nByPCS,
      V_Integer2     = @nByLOTS,
      V_Integer3     = @nDefaultQty, 
      
      V_String3      = @cLabelNo,
      V_String4      = @cCartonType,
      V_String5      = @cDOID,
      V_String7      = @cSectionKey, 

      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15,

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
END

GO
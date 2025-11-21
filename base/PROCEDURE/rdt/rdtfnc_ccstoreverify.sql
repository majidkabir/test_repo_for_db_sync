SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_CCStoreVerify                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick consolidation                                          */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 17-Mar-2014 1.0  James    SOS322458 - Created                        */
/* 02-Jan-2015 1.1  James    SOS321766 & 332387-Add open new sack screen*/
/*                           Add ExtendedInfoSP (james01)               */
/* 30-Sep-2016 1.2  Ung      Performance tuning                         */
/* 30-Oct-2018 1.3  TungGH   Performance                                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CCStoreVerify] (
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
   @c_errmsg        NVARCHAR(250) 
   
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

   @cOrderKey           NVARCHAR( 10),
   @cFinalLOC           NVARCHAR( 10),
   @cPrinter            NVARCHAR( 10),
   @cPrinter_Paper      NVARCHAR( 10),
   @cBagLabel           NVARCHAR( 20),
   @cSuggestedLOC       NVARCHAR( 10),
   @cStore              NVARCHAR( 15),
   @cCompany            NVARCHAR( 45),
   @cAddr1              NVARCHAR( 45),
   @cAddr2              NVARCHAR( 45),
   @cAddr3              NVARCHAR( 45),
   @cAddr4              NVARCHAR( 45),
   @cCity               NVARCHAR( 45),
   @cZip                NVARCHAR( 18),

   @cErrMsg1            NVARCHAR( 20),  
   @cErrMsg2            NVARCHAR( 20),  
   @cErrMsg3            NVARCHAR( 20),  
   @cErrMsg4            NVARCHAR( 20),  
   @cErrMsg5            NVARCHAR( 20),  
   
   @cOption             NVARCHAR( 1),     -- (james01)
   @cPickSlipNo         NVARCHAR( 10),    -- (james01)
   @cLabelNo            NVARCHAR( 20),    -- (james01)
   @bSuccess            INT,              -- (james01)
   @cExtendedInfoSP     NVARCHAR( 20),    -- (james01)
   @cExtendedInfo       NVARCHAR( 20),    -- (james01)
   @cSQL                NVARCHAR(1000),   -- (james01)
   @cSQLParam           NVARCHAR(1000),   -- (james01)
   @cDataWindow         NVARCHAR( 50),    -- (james01)
   @cLabelPrinter       NVARCHAR( 10),    -- (james01)    
   @cTargetDB           NVARCHAR( 20),    -- (james01)    
   
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

   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @cLabelPrinter    = Printer,
   @cPrinter_Paper   = Printer_Paper, 

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cOrderKey        = V_OrderKey, 
   @cSuggestedLOC    = V_LOC, 

   @cBagLabel        = V_String1, 
   @cStore           = V_String2, 
   @cZip             = V_String3, 
   
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

IF @nFunc = 536
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0    -- Menu. Func = 536
   IF @nStep = 1  GOTO Step_1    -- Scn = 3790. ORDERKEY
   IF @nStep = 2  GOTO Step_2    -- Scn = 3791. Store info, FINAL LOC
   IF @nStep = 3  GOTO Step_3    -- Scn = 3792. Open new sack
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 536. Screen 0.
********************************************************************************/
Step_0:
BEGIN
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

   -- Prev next screen var
   SET @cBagLabel = ''

   SET @cOutField01 = ''

   SET @nScn = 3970
   SET @nStep = 1
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 3970. Screen 1.
   C&C Label   (field01)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBagLabel = @cInField01   
      
      -- Validate blank
      IF ISNULL(@cBagLabel, '') = ''
      BEGIN
         SET @nErrNo = 91951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label needed
         GOTO Step_1_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   LabelNo = @cBagLabel)
      BEGIN
         SET @nErrNo = 91952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID Label
         GOTO Step_1_Fail
      END

      SET @cOrderKey = SUBSTRING( RTRIM( @cBagLabel), 3, 10)

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   OrderKey = @cOrderKey
                      AND   [Status] >= '5')
      BEGIN
         SET @nErrNo = 91953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID ORDERS
         GOTO Step_1_Fail
      END

      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      SET @cExtendedInfo = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBagLabel, @cOrderKey, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile          INT,           ' +
               '@nFunc            INT,           ' +
               '@cLangCode        NVARCHAR( 3),  ' +
               '@nStep            INT,           ' +
               '@nInputKey        INT,           ' +
               '@cStorerkey       NVARCHAR( 15), ' +
               '@cBagLabel        NVARCHAR( 20), ' +
               '@cOrderKey        NVARCHAR( 10), ' +
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT,  ' +
               '@nErrNo           INT           OUTPUT,  ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBagLabel, @cOrderKey, 
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            SET @cStore = @cExtendedInfo
         END
      END
      ELSE
      BEGIN
         -- Click & Collect is ECOMM orders, so no consigneekey in orders table
         -- Get zip code from c&c orders to retrieve which store it goes to
         SET @cZip = ''
         SELECT @cZip = C_Zip
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

         -- From Orders.C_Zip then check in storer table to retrieve store information
         SET @cStore = ''
         SELECT TOP 1 @cStore = StorerKey 
         FROM dbo.Storer WITH (NOLOCK) 
         WHERE Zip = @cZip 
         AND   Consigneefor = 'JACKW'
         AND   Type = '2'

         IF ISNULL( @cStore, '') = ''
         BEGIN
            SET @nErrNo = 0  
            SET @cErrMsg1 = 'NO STORE FOUND'  
            SET @cErrMsg2 = 'FOR ZIP CODE:'  
            SET @cErrMsg3 = @cZip  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
               @cErrMsg1, @cErrMsg2, @cErrMsg3  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg2 = ''  
               SET @cErrMsg3 = ''  
            END  
            GOTO Step_1_Fail  
         END
      END

      SET @cCompany = ''
      SET @cAddr1 = ''
      SET @cAddr2 = ''
      SET @cAddr3 = ''
      SET @cAddr4 = ''
      SET @cCity = ''

      SELECT @cCompany = Company, 
             @cAddr1 = Address1,   
             @cAddr2 = Address2,   
             @cAddr3 = Address3,   
             @cAddr4 = Address4,   
             @cCity = City   
      FROM dbo.Storer WITH (NOLOCK) 
      WHERE StorerKey = @cStore
      AND   Type = '2'

      SET @cSuggestedLOC = ''

      /*
      -- Check for DPK type of picking first. DPK type PTS LOC located @ PickDetail.LOC
      SELECT TOP 1 @cSuggestedLOC = PD.LOC 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE PD.StorerKey = @cStorerKey
      AND   O.ConsigneeKey = @cStore
      AND   PD.Status = '5' -- picked & start pack 1st item
      AND   ISNULL( PD.AltSKU, '') <> '' -- Sack that already start packing 
      AND   TD.TaskType = 'DPK' 
      AND   LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') -- dynamic pick location only
      AND   EXISTS ( SELECT 1 FROM dbo.STORETOLOCDETAIL ST (NOLOCK) WHERE PD.LOC = ST.LOC AND ST.Status = '1')
      ORDER BY PD.LOC

      -- If no DPK type PTS LOC then look for SPK type
      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         SELECT TOP 1 @cSuggestedLOC = TD.ToLOC 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
         AND   O.ConsigneeKey = @cStore
         AND   PD.Status = '5' -- picked
         AND   ISNULL( PD.AltSKU, '') <> '' -- Sack that already start packing 
         AND   TD.TaskType = 'SPK' 
         AND   LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') -- dynamic pick location only
         AND   EXISTS ( SELECT 1 FROM dbo.STORETOLOCDETAIL ST (NOLOCK) WHERE TD.ToLOC = ST.LOC AND ST.Status = '1')
         ORDER BY TD.ToLOC
      END

      
      -- If no open sack then just suggest them a default PTS LOC
      IF ISNULL( @cSuggestedLOC, '') = ''
         SELECT TOP 1 @cSuggestedLOC = LOC FROM dbo.STORETOLOCDETAIL (NOLOCK) 
         WHERE ConsigneeKey = @cStore
         AND   [Status] = '1'

      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         SET @nErrNo = 91954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO SUGGEST LOC
         GOTO Step_1_Fail
      END
      */

      SELECT TOP 1 @cSuggestedLOC = STL.LOC 
      FROM dbo.StoreToLocDetail STL WITH (NOLOCK) 
      JOIN dbo.Storer ST WITH (NOLOCK) ON ( STL.ConsigneeKey = ST.StorerKey )
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (STL.LOC = LOC.LOC)
      WHERE STL.Status = '1'
      AND   ST.Consigneefor = 'JACKW' 
      AND   ST.Zip = @cZip
      AND   ST.Type = '2'
      ORDER BY 1

      -- (james01)
      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         SET @cOutField01 = '' 

         -- Go to next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cBagLabel 
         SET @cOutField02 = @cCompany 
         SET @cOutField03 = @cAddr1 
         SET @cOutField04 = @cAddr2 
         SET @cOutField05 = @cAddr3 
         SET @cOutField06 = @cAddr4 
         SET @cOutField07 = @cCity 
         SET @cOutField08 = @cZip 
         SET @cOutField09 = @cSuggestedLOC           
         SET @cOutField10 = ''           

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
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
      SET @cBagLabel = ''

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
      -- Reset this screen var
      SET @cOutField01 = ''
      SET @cBagLabel = ''
   END
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 3971. Screen 2.
   ORDERKEY          (field01)   
   COMPANY           (field02)   
   ADDRESS           (field03)   
   FINAL LOC         (field04)   - Input field
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField10
      SET @cOption = @cInField11

      IF ISNULL( @cOption, '') <> ''
      BEGIN
         IF @cOption = '1'
         BEGIN
            SET @cOutField01 = '' 

            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 91961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid Option'
            GOTO Step_2_Fail
         END
      END

      IF ISNULL(@cFinalLOC, '') = ''
      BEGIN
         SET @nErrNo = 91955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'TO LOC req'
         GOTO Step_2_Fail
      END      

      IF RTRIM( @cSuggestedLOC) <> ISNULL( RTRIM( @cFinalLOC), '') 
      BEGIN
         SET @nErrNo = 91956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID LOC'
         GOTO Step_2_Fail
      END      

      -- just to keep a record of what bag scanned.
      INSERT INTO rdt.rdtPickConsoLog (Orderkey, PickZone, SKU, LOC, [Status], AddWho, AddDate, Mobile) VALUES 
      (@cOrderKey, '', @cBagLabel, @cFinalLOC, '9', sUser_sName(), GETDATE(), @nMobile)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 91957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD HISTORY ERR'
         GOTO Step_2_Fail
      END      

      -- Prev next screen var
      SET @cBagLabel = ''

      SET @cOutField01 = ''
   
      -- Go to screen 3
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prev next screen var
      SET @cBagLabel = ''

      SET @cOutField01 = ''
   
      -- Go to screen 3
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SELECT @cCompany = Company, 
             @cAddr1 = Address1,   
             @cAddr2 = Address2,   
             @cAddr3 = Address3,   
             @cAddr4 = Address4,   
             @cCity = City   
      FROM dbo.Storer WITH (NOLOCK) 
      WHERE StorerKey = @cStore
      AND   Type = '2'

      -- Prep next screen var
      SET @cOutField01 = @cBagLabel 
      SET @cOutField02 = @cCompany 
      SET @cOutField03 = @cAddr1 
      SET @cOutField04 = @cAddr2 
      SET @cOutField05 = @cAddr3 
      SET @cOutField06 = @cAddr4 
      SET @cOutField07 = @cCity 
      SET @cOutField08 = @cZip 
      SET @cOutField09 = @cSuggestedLOC           
      SET @cOutField10 = ''           
   END
END
GOTO Quit

/************************************************************************************
Step_3. Scn = 3972. Screen 3.
   NO OPEN SACK. CREATE NEW?
   OPTION      (field01)   - Input field
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01   

      IF ISNULL(@cOption, '') = '' 
      BEGIN  
         SET @nErrNo = 91958  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'  
         GOTO Step_3_Fail  
      END  
  
      IF ISNULL(RTRIM(@cOption), '') NOT IN ('1', '9')
      BEGIN  
         SET @nErrNo = 91959  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_3_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN  
         -- ECOMM orders, 1 orders 1 bag, 1 label
         SELECT @cPickSlipNo = PD.PickSlipNo, @cLabelNo = PD.LabelNo 
         FROM dbo.PackHeader PH WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         WHERE PH.StorerKey = @cStorerKey
         AND   PH.OrderKey = @cOrderKey

         EXEC [dbo].[isp_WS_TNT_ExpressLabel] 
             @nMobile,         
             @cPickSlipNo,     
             1,       
             @cLabelNo,        
             @bSuccess        OUTPUT,  
             @nErrNo          OUTPUT,  
             @cErrMsg         OUTPUT 

         IF @bSuccess <> 1
         BEGIN  
            SET @nErrNo = 91960  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
            GOTO Step_3_Fail  
         END  

         -- Get report info  
         SET @cDataWindow = ''  
         SET @cTargetDB = ''  
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
         FROM RDT.RDTReport WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
         AND   ReportType = 'SORTTNTLBL'   
                  
         -- Insert print job  
         SET @nErrNo = 0                    
         EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            'SORTTNTLBL',                    
            'PRINT_SORTTNTLABEL',                    
            @cDataWindow,                    
            @cLabelPrinter,                    
            @cTargetDB,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cBagLabel,    
            @cStorerKey       

         IF @nErrNo = 0
         BEGIN
            IF ISNULL( @cSuggestedLOC, '') = ''
            BEGIN            
               -- Get the available loc to put the sack
               SELECT TOP 1 @cSuggestedLOC = LOC 
               FROM dbo.STORETOLOCDETAIL ST (NOLOCK) 
               WHERE ConsigneeKey = @cStore
               AND   [Status] = '1'
               AND NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                                WHERE PD.LOC = ST.LOC
                                AND   PD.StorerKey = @cStorerKey
                                AND   PD.Status < '9')
               ORDER BY ST.LOC
            END

            -- If no empty loc to put open sack then just suggest them a default PTS LOC
            IF ISNULL( @cSuggestedLOC, '') = ''
            BEGIN
               SELECT TOP 1 @cSuggestedLOC = LOC FROM dbo.STORETOLOCDETAIL (NOLOCK) 
               WHERE ConsigneeKey = @cStore
               AND   [Status] = '1'
               ORDER BY 1
            END

            IF ISNULL( @cSuggestedLOC, '') = ''
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = 'NO SUGGESTED LOC.'
               SET @cErrMsg2 = 'PLS PUT BAG INTO'
               SET @cErrMsg3 = 'SACK'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = 'SUGGESTED LOC:'
               SET @cErrMsg2 = @cSuggestedLOC
               SET @cErrMsg3 = 'PLS PUT BAG INTO'
               SET @cErrMsg4 = 'SACK'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
               END
            END
         END
      END

      -- Prev next screen var
      SET @cBagLabel = ''

      SET @cOutField01 = ''

      SET @nScn = 3970
      SET @nStep = 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset variable
      SET @cBagLabel = ''

      SET @cOutField01 = ''

      -- Go back screen 1
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = ''
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
      Printer        = @cLabelPrinter,
      Printer_Paper  = @cPrinter_Paper,
      
      V_OrderKey     = @cOrderKey, 
      V_LOC          = @cSuggestedLOC, 

      V_String1      = @cBagLabel,
      V_String2      = @cStore,     
      V_String3      = @cZip, 
   
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
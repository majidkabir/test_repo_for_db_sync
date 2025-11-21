SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtfnc_TMS_CartonToPallet                              */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2018-05-16   1.0  ChewKP   WMS-4962 Created                             */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_TMS_CartonToPallet](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE 
   @nCnt           INT, 
   @cReport        NVARCHAR( 20),
   @cParam1        NVARCHAR( 60),--(ChewKP03)
   @cParam2        NVARCHAR( 60),--(ChewKP03)
   @cParam3        NVARCHAR( 60),--(ChewKP03)
   @cParam4        NVARCHAR( 60),--(ChewKP03)
   @cParam5        NVARCHAR( 60),--(ChewKP03)
   @curLabelReport CURSOR

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),
   @cPrinter_Paper NVARCHAR( 10), 
   
   @nPallet        INT,
   @nCaseCnt       INT,
 
   @cPalletSKU          NVARCHAR(20),
   @cPalletStorerKey    NVARCHAR(15),
   @cRefNo              NVARCHAR(20),
   @cPackKey            NVARCHAR(10),
   @nTTLPallet          INT,
   @nTTLCount           INT,
   @cOrderKey           NVARCHAR(10),
   @cPalletID           NVARCHAR(18),
   @nFromStep           INT,
   
   @cOption             NVARCHAR(1),
   @cPickSlipNo         NVARCHAR(10),
   @nCartonCount        INT,
   @cExternOrderKey     NVARCHAR(20),
   @cConsigneeKey       NVARCHAR(15),
   @cOverScanMsg        NVARCHAR(20),
   @nCount              INT,
   @cCaseID             NVARCHAR(20),
   @cOTMCaseID          NVARCHAR(20),
   @bSuccess            INT,
   @cCartonNo           NVARCHAR(20), 
   @nSKUCount           INT,
   @nSumTotalQty        INT,
   @nPDQty              INT,
   @nMUID               INT,
   @cOTMIDTrackCaseID   NVARCHAR(20),
   @cLoosePallet        NVARCHAR(1),
   @nTotalCtnPerQty     INT,
   @nOTMCtnCount        INT,
   @cID                 NVARCHAR(18),
   @cUOM                NVARCHAR(10),
   @cPDUOM              NVARCHAR(10),
   @nCountUOM           INT,
   @cTrackingNo         NVARCHAR(30),
   @cOTMIDtrackStorerKey NVARCHAR(15),

   
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
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper, 

   @cRefNo           = V_String1,
   @cOrderKey        = V_String2,

   @cPalletStorerKey = V_String3,
   @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4,  5), 0) = 1 THEN LEFT( V_String4,  5) ELSE 0 END,
   @cPalletID        = V_String5,
   @nCartonCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
   @nTTLPallet       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7,  5), 0) = 1 THEN LEFT( V_String7,  5) ELSE 0 END,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1189
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0       -- Menu. Func = 1189
   IF @nStep = 1  GOTO Step_1       -- Scn = 5160. Pallet ID
   IF @nStep = 2  GOTO Step_2       -- Scn = 5161. RefNo
   IF @nStep = 3  GOTO Step_3       -- Scn = 5162. TTL Carton
   IF @nStep = 4  GOTO Step_4       -- Scn = 5163. Carton No 
   IF @nStep = 5  GOTO Step_5       -- Scn = 5164. Options
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1189
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
      
   -- Prepare next screen var
   
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey
   
   -- Go to next screen
   SET @nScn = 5160
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 5160. 
   Pallet ID  (field01)
   
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField01

      -- Check blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 124101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDReq
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
                 WHERE PalletKey = @cPalletID
                 AND MUStatus = '1' )
      BEGIN
         SET @nErrNo = 124120
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDClose
         GOTO Step_1_Fail
      END

      -- Check option valid
      IF EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
                 WHERE PalletKey = @cPalletID
                 AND MUStatus = '0' )
      BEGIN
         SELECT TOP 1 @cOrderKey = OrderID
         FROM dbo.OTMIDTrack WITH (NOLOCK) 
         WHERE PalletKey = @cPalletID
         AND MUStatus = '0'
         
         SELECT @nTTLCount = COUNT(MUID)
         FROM dbo.OTMIDTrack WITH (NOLOCK) 
         WHERE PalletKey = @cPalletID
         AND MUStatus = '0'
--         
--         
--         
--         SELECT TOP 1 @cPalletSKU       = SKU 
--                     ,@cPalletStorerKey = StorerKey
--         FROM dbo.OrderDetail WITH (NOLOCK) 
--         WHERE OrderKey = @cOrderKey         
--         
--         SELECT @cPackKey = PackKey 
--         FROM dbo.SKU WITH (NOLOCK) 
--         WHERE StorerKey = @cPalletStorerKey
--         AND SKU = @cPalletSKU 
--         
--         SELECT @nPallet = Pallet
--               ,@nCaseCnt = CaseCnt
--         FROM dbo.Pack WITH (NOLOCK) 
--         WHERE PackKey = @cPackKey
--         
--         SET @nTTLPallet =  @nPallet / @nCaseCnt
         
         SET @nFromStep = @nStep
         
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cOrderKey
         SET @cOutField03 = @nTTLPallet
         SET @cOutField04 = @nTTLCount
         SET @cOutField05 = ''
         
          -- Go to next screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
         
         GOTO QUIT 
      END
      
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
      
                           

   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey
      
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOption = ''
      SET @cOutField01 = '' 

      -- Enable field
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      
      SET @cOutField01 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5161. screen
   PalletID       (field01)
   RefNo          (field02, input)
   
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField02

      --SET @cRefNo = '0012461878'

           
      IF ISNULL(@cRefNo ,'' ) = '' 
      BEGIN
         SET @nErrNo = 124102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNoReq
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                      WHERE ExternOrderKey = @cRefNo)
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                         WHERE OrderKey = @cRefNo )
         BEGIN
            SET @nErrNo = 124103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidRefNo
            GOTO Step_2_Fail
         END
         ELSE 
         BEGIN
            SELECT @cPalletStorerKey = StorerKey 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE OrderKey = @cRefNo 
            
            SET @cOrderKey = @cRefNo 
         END
      END
      ELSE
      BEGIN
            SELECT @cOrderKey = OrderKey
                  ,@cPalletStorerKey = StorerKey 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE ExternOrderKey = @cRefNo 
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                  WHERE StorerKey = @cPalletStorerKey
                  AND OrderKey = @cOrderKey
                  AND Status <> '9')
      BEGIN
         SET @nErrNo = 124104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvOrdStatus
         GOTO Step_2_Fail
      END
     
      IF NOT EXISTS (SELECT 1 FROM dbo.POD WITH (NOLOCK) 
                     WHERE OrderKey = @cOrderKey
                     AND PODDef06 = 'Y')
      BEGIN
          
         SET @nErrNo = 124105
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PODDocReq
         
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
          @cActionType = '3', 
          @cUserID     = @cUserName,
          @nMobileNo   = @nMobile,
          @nFunctionID = @nFunc,
          @cFacility   = @cFacility,
          @cStorerKey  = @cStorerkey,
          @cOrderKey   = @cOrderKey,
          @cID         = @cPalletID,
          @cDropID     = '',
          @cRefNo1    = @nErrNo,
          @cRefNo2    = @cErrMsg
          
         GOTO Step_2_Fail
         
      END

      SET @nOTMCtnCount = 0
      SET @nTTLPallet = 0 
      SET @cLoosePallet = 0
      SET @nTotalCtnPerQty = 0 
      
--      IF EXISTS ( SELECT 1 FROM dbo.Pickdetail WITH (NOLOCK) 
--                  WHERE StorerKey = @cPalletStorerKey
--                  AND OrderKey = @cOrderKey
--                  AND ID = @cPalletID ) 
--                  --AND UOM = '1')
--      BEGIN
--         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
--                         WHERE StorerKey = @cPalletStorerKey
--                         AND OrderKey = @cOrderKey
--                         AND ID = @cPalletID )
--         BEGIN
--            SET @nErrNo = 124125
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
--            GOTO Step_2_Fail   
--         END
      DECLARE @curRDID CURSOR

      IF EXISTS ( SELECT 1 FROM dbo.Pickdetail WITH (NOLOCK) 
                  WHERE StorerKey = @cPalletStorerKey
                  AND OrderKey = @cOrderKey
                  AND ID = @cPalletID ) 
      BEGIN
         SET @curRDID = CURSOR FOR 
           
         SELECT ID, SKU, SUM(Qty), UOM
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cPalletStorerKey
         AND OrderKey = @cOrderKey
         AND ID = @cPalletID
         --AND UOM <> 1 
         Group By ID, SKU , UOM 
      
      
         OPEN @curRDID
         FETCH NEXT FROM @curRDID INTO @cID, @cPalletSKU, @nPDQty, @cPDUOM
         WHILE @@FETCH_STATUS = 0
         BEGIN
         
            SET @nCaseCnt = 0 
            SET @nPallet  = 0
            SET @cPackKey = ''
         
   --         SELECT TOP 1  @cPalletSKU = SKU 
   --               ,@nSumTotalQty = SUM(Qty)
   --         FROM dbo.PickDetail  WITH (NOLOCK) 
   --         WHERE OrderKey = @cOrderKey         
   --         --AND DropID = @cPalletID
   --         GROUP BY SKU
         
            SELECT @cPackKey = PackKey 
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cPalletStorerKey
            AND SKU = @cPalletSKU 
         
            SELECT @nPallet = Pallet
                  ,@nCaseCnt = CaseCnt
            FROM dbo.Pack WITH (NOLOCK) 
            WHERE PackKey = @cPackKey
      
         
            IF @cPDUOM = '1'
            BEGIN
               --IF @cID <> @cPalletID 
               --BEGIN
               --   SET @nErrNo = 124126
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
               --   GOTO Step_2_Fail
               --END
               
               SET @nTotalCtnPerQty = @nTotalCtnPerQty + (@nPallet / @nCaseCnt)
            END
            ELSE IF @cPDUOM <> '1'
            BEGIN
                
               
            
               IF @nPDQty = @nPallet 
               BEGIN
                  SET @nTotalCtnPerQty = @nTotalCtnPerQty + (@nPallet / @nCaseCnt)
               END
            
            END
         
            --IF @nPDQty >= @nPallet 
            --BEGIN
            
               --SET @nTTLPallet = @nTTLPallet + ( @nPDQty / @nCaseCnt)
            --   SET @nTotalCtnPerQty = @nTotalCtnPerQty + (@nPallet / @nCaseCnt)
      
               --SELECT @nPallet '@nPallet' , @nCaseCnt '@nCaseCnt' , @nPDQty '@nPDQty' , @nTTLPallet '@nTTLPallet' , @nTotalCtnPerQty '@nTotalCtnPerQty'
            --END
                     
            FETCH NEXT FROM @curRDID INTO @cID, @cPalletSKU, @nPDQty, @cPDUOM
         END
      
      END
      ELSE
      BEGIN
         
         -- Else for Validation 
         SET @nCountUOM = 0 
         SELECT @nCountUOM = Count (Distinct UOM )
         FROM dbo.PickDetail (NOLOCK)
         WHERE StorerKey = @cStorerKey 
         AND OrderKey = @cOrderKey 

         
         
         IF @nCountUOM = 1 
         BEGIN
            
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey 
                        AND OrderKey = @cOrderKey
                        AND UOM = '1' )
            BEGIN
                SET @nErrNo = 124127
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
                GOTO Step_2_Fail
            END
            ELSE
            BEGIN
                 
               SET @curRDID = CURSOR FOR 
                 
               SELECT ID, SKU, SUM(Qty)
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cPalletStorerKey
               AND OrderKey = @cOrderKey
               AND UOM = '6'
               Group By ID, SKU , UOM 
            
            
               OPEN @curRDID
               FETCH NEXT FROM @curRDID INTO @cID, @cPalletSKU, @nPDQty
               WHILE @@FETCH_STATUS = 0
               BEGIN
               
                  SET @nCaseCnt = 0 
                  SET @nPallet  = 0
                  SET @cPackKey = ''
               
                  SELECT @cPackKey = PackKey 
                  FROM dbo.SKU WITH (NOLOCK) 
                  WHERE StorerKey = @cPalletStorerKey
                  AND SKU = @cPalletSKU 
               
                  SELECT @nPallet = Pallet
                        ,@nCaseCnt = CaseCnt
                  FROM dbo.Pack WITH (NOLOCK) 
                  WHERE PackKey = @cPackKey

                  
                  --SELECT @nPallet '@nPallet' , @nPDQty '@nPDQty'  , @cPalletID '@cPalletID' , @cPalletStorerKey '@cPalletStorerKey' 

                  IF @nPDQty = @nPallet 
                  BEGIN
                        IF NOT EXISTS ( SELECT 1 FROM OTMIDTrack WITH (NOLOCK) 
                                 WHERE PalletKey = @cID
                                 AND Principal = @cPalletStorerKey ) 
                        BEGIN
                           SET @nErrNo = 124128
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
                           GOTO Step_2_Fail
                        END
                  END
                  

                  FETCH NEXT FROM @curRDID INTO @cID, @cPalletSKU, @nPDQty
               END
            END
         END
      END


      SELECT @nOTMCtnCount = ISNULL(COUNT(MUID),0) 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE Principal = @cPalletStorerKey
      AND OrderID = @cOrderKey
      AND PalletKey = @cPalletID
      
      --SELECT @nTotalCtnPerQty '@nTotalCtnPerQty' , @nOTMCtnCount '@nOTMCtnCount' 
      
      IF @nOTMCtnCount = 0 AND @nTotalCtnPerQty > 0 
      BEGIN
         SET @cLoosePallet = '0'
         SET @nTTLPallet = @nTotalCtnPerQty 
      END
      ELSE
      BEGIN
         SET @cLoosePallet = '1'
         
      END
      
      IF @cLoosePallet = '0'
      BEGIN
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5)) 
         SET @cOutField04 = ''
      
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         

--         SELECT @cPickSlipNo = PickSlipNo 
--         FROM dbo.PackHeader WITH (NOLOCK) 
--         WHERE OrderKey = @cOrderKey
      
--         IF NOT EXISTS ( SELECT 1 FROM dbo.PacKInfo WITH (NOLOCK) 
--                         WHERE PickSlipNo = @cPickSlipNo )
--         BEGIN
--            SET @nErrNo = 124125
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPackInfo
--            GOTO Step_2_Fail
--         END
      
                 
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = ''
      
         -- Go to next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
--         SELECT TOP 1 @cPalletSKU = SKU 
--         FROM dbo.PickDetail  WITH (NOLOCK) 
--         WHERE OrderKey = @cOrderKey         
--         --AND DropID = @cPalletID
--         
--         SELECT @cPackKey = PackKey 
--         FROM dbo.SKU WITH (NOLOCK) 
--         WHERE StorerKey = @cPalletStorerKey
--         AND SKU = @cPalletSKU 
--         
--         SELECT @nPallet = Pallet
--               ,@nCaseCnt = CaseCnt
--         FROM dbo.Pack WITH (NOLOCK) 
--         WHERE PackKey = @cPackKey
--
--         SET @nTTLPallet =  @nPallet / @nCaseCnt
--         
--         SET @cOutField01 = @cPalletID
--         SET @cOutField02 = @cRefNo
--         SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5)) 
--         SET @cOutField04 = ''
--
--         -- Go to next screen
--         SET @nScn = @nScn + 1
--         SET @nStep = @nStep + 1
         
--      END
--      ELSE IF NOT EXISTS ( SELECT 1 FROM dbo.Pickdetail WITH (NOLOCK) 
--                        WHERE StorerKey = @cPalletStorerKey
--                        AND OrderKey = @cOrderKey
--                        AND ID = @cPalletID ) 
--                        --AND UOM <> '1')
--
--      BEGIN
--
--      
-- 
--         
--         DECLARE @curRD CURSOR
--         SET @curRD = CURSOR FOR 
--         
--         SELECT SKU, SUM(Qty)
--         FROM dbo.PickDetail WITH (NOLOCK) 
--         WHERE StorerKey = @cPalletStorerKey
--         AND OrderKey = @cOrderKey
--         --AND ID = @cPalletID
--         --AND UOM <> 1 
--         Group By SKU
--         
--         
--         OPEN @curRD
--         FETCH NEXT FROM @curRD INTO @cPalletSKU, @nPDQty 
--         WHILE @@FETCH_STATUS = 0
--         BEGIN
--            
--            SET @nCaseCnt = 0 
--            SET @nPallet  = 0
--            SET @cPackKey = ''
--            
----            SELECT TOP 1  @cPalletSKU = SKU 
----                  ,@nSumTotalQty = SUM(Qty)
----            FROM dbo.PickDetail  WITH (NOLOCK) 
----            WHERE OrderKey = @cOrderKey         
----            --AND DropID = @cPalletID
----            GROUP BY SKU
--            
--            SELECT @cPackKey = PackKey 
--            FROM dbo.SKU WITH (NOLOCK) 
--            WHERE StorerKey = @cPalletStorerKey
--            AND SKU = @cPalletSKU 
--            
--            SELECT @nPallet = Pallet
--                  ,@nCaseCnt = CaseCnt
--            FROM dbo.Pack WITH (NOLOCK) 
--            WHERE PackKey = @cPackKey
--
--            
--
--            IF @nPDQty >= @nPallet 
--            BEGIN
--               
--               --SET @nTTLPallet = @nTTLPallet + ( @nPDQty / @nCaseCnt)
--               SET @nTotalCtnPerQty = @nTotalCtnPerQty + (@nPallet / @nCaseCnt)
--
--               --SELECT @nPallet '@nPallet' , @nCaseCnt '@nCaseCnt' , @nPDQty '@nPDQty' , @nTTLPallet '@nTTLPallet' , @nTotalCtnPerQty '@nTotalCtnPerQty'
--            END
--                        
--            FETCH NEXT FROM @curRD INTO @cPalletSKU, @nPDQty 
--         END
--
--         SELECT @nOTMCtnCount = ISNULL(COUNT(MUID),0) 
--         FROM dbo.OTMIDTrack WITH (NOLOCK) 
--         WHERE Principal = @cPalletStorerKey
--         AND OrderID = @cOrderKey
--         AND PalletKey = @cPalletID
--
--         --SELECT @nTotalCtnPerQty '@nTotalCtnPerQty' , @nOTMCtnCount '@nOTMCtnCount' 
--
--         IF @nOTMCtnCount = 0 AND @nTotalCtnPerQty > 0 
--         BEGIN
--            SET @cLoosePallet = '0'
--            SET @nTTLPallet = @nTotalCtnPerQty 
--         END
--         ELSE
--         BEGIN
--            SET @cLoosePallet = '1'
--            
--         END
--         
--         IF @cLoosePallet = '0'
--         BEGIN
--            SET @cOutField01 = @cPalletID
--            SET @cOutField02 = @cRefNo
--            SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5)) 
--            SET @cOutField04 = ''
--
--            -- Go to next screen
--            SET @nScn = @nScn + 1
--            SET @nStep = @nStep + 1
--         END
--         ELSE
--         BEGIN
--            SELECT @cPickSlipNo = PickSlipNo 
--            FROM dbo.PackHeader WITH (NOLOCK) 
--            WHERE OrderKey = @cOrderKey
--         
--            IF NOT EXISTS ( SELECT 1 FROM dbo.PacKInfo WITH (NOLOCK) 
--                            WHERE PickSlipNo = @cPickSlipNo )
--            BEGIN
--               SET @nErrNo = 124112
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPackInfo
--               GOTO Step_2_Fail
--            END
--         
--                    
--            SET @cOutField01 = @cPalletID
--            SET @cOutField02 = @cRefNo
--            SET @cOutField03 = ''
--
--            -- Go to next screen
--            SET @nScn = @nScn + 2
--            SET @nStep = @nStep + 2
--         END
--
--
--      END
      --ELSE
      --BEGIN
      --   SELECT @cPickSlipNo = PickSlipNo 
      --   FROM dbo.PackHeader WITH (NOLOCK) 
      --   WHERE OrderKey = @cOrderKey
         
      --   IF NOT EXISTS ( SELECT 1 FROM dbo.PacKInfo WITH (NOLOCK) 
      --                   WHERE PickSlipNo = @cPickSlipNo )
      --   BEGIN
      --      SET @nErrNo = 124112
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPackInfo
      --      GOTO Step_2_Fail
      --   END
         
                    
      --   SET @cOutField01 = @cPalletID
      --   SET @cOutField02 = @cRefNo
      --   SET @cOutField03 = ''

      --   -- Go to next screen
      --   SET @nScn = @nScn + 2
      --   SET @nStep = @nStep + 2
      --END
  
      
      
      
      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''--@cPalletID
      SET @cOutField02 = ''
      
      
      -- Go to next screen
      SET @nScn = @nScn - 1 
      SET @nStep = @nStep - 1 
   END
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
      
      SET @cOutField02 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5162. screen
   PalletID       (field01)
   RefNo          (field02)
   TTL Carton     (field03, input)
***********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @nCartonCount = @cInField04

      --SET @nCartonCount = 112 
      
      IF ISNULL(@nCartonCount ,'0' ) = '0' 
      BEGIN
         SET @nErrNo = 124106
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyReq
         GOTO Step_3_Fail
      END
          
      -- Validate QTY
      IF rdt.rdtIsValidQty( @nCartonCount, 21) = 0
      BEGIN
         SET @nErrNo = 124107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InvalidQty
         GOTO Step_3_Fail
      END
      
      SELECT @cExternOrderKey = ExternOrderKey
            ,@cConsigneeKey   = ConsigneeKey
      FROM dbo.OrderS WITH (NOLOCK) 
      WHERE StorerKey = @cPalletStorerKey
      AND OrderKey = @cOrderKey
      
--      SELECT TOP 1 @cPalletSKU = SKU 
--      FROM dbo.PickDetail  WITH (NOLOCK) 
--      WHERE OrderKey = @cOrderKey         
      --AND DropID = @cPalletID
      
--      SELECT @cPackKey = PackKey 
--      FROM dbo.SKU WITH (NOLOCK) 
--      WHERE StorerKey = @cPalletStorerKey
--      AND SKU = @cPalletSKU 
--      
--      SELECT @nPallet = Pallet
--            ,@nCaseCnt = CaseCnt
--      FROM dbo.Pack WITH (NOLOCK) 
--      WHERE PackKey = @cPackKey
--
--      SET @nTTLPallet =  @nPallet / @nCaseCnt
      
      

--      IF @nTTLPallet > CAST (@nCartonCount AS INT)
--      BEGIN
--         -- GOTO SHORT SCREEN
--         
--         SET @cOutField01 = @cPalletID
--         SET @cOutField02 = @cRefNo
--         SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5) ) 
--         SET @cOutField04 = @nCartonCount
--         SET @cOutField05 = ''
--         
--         SET @nFromStep = @nStep 
--         
--         SET @nScn = @nScn + 2
--         SET @nStep = @nStep + 2
--         
--         GOTO QUIT 
--         
--      END
      
      

      SET @cOverScanMsg = '' 
      IF CAST( @nCartonCount AS INT ) > @nTTLPallet
         SET @cOverScanMsg = 'Over Scanned'
      ELSE IF CAST( @nCartonCount AS INT ) = @nTTLPallet         
         SET @cOverScanMsg = 'Normal'
      ELSE IF CAST( @nCartonCount AS INT ) < @nTTLPallet         
         SET @cOverScanMsg = 'Short Qty'   
      
      SET @nCount = 1
      
      WHILE @nCartonCount >= @nCount
      BEGIN
         SET @cCaseID = ''  
         SET @cOTMCaseID = ''
         
--         SET @bSuccess = 1  
--         EXECUTE dbo.nspg_getkey  
--          'OTMCaseID'  
--          , 4  
--          , @cCaseID           OUTPUT  
--          , @bSuccess          OUTPUT  
--          , @nErrNo            OUTPUT  
--          , @cErrMsg           OUTPUT  
--          
--         IF @bSuccess <> 1  
--         BEGIN  
--            SET @nErrNo = 124109  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
--            GOTO Step_3_Fail  
--         END  
         --SET @cCaseID = RIGHT('0000'+CAST(@nCount AS VARCHAR(4)),4)
         SET @cOTMCaseID =  @cPalletID  + CAST(@nCount AS NVARCHAR(4) ) 
         
         -- Insert Into OTMIDTrack --
         INSERT INTO dbo.OTMIDTrack (PalletKey, Principal, MUStatus, OrderID, CaseID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume, TrackingNo,
                                    MUType, DropLoc, ExternOrderKey, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )
                                  
         VALUES ( @cPalletID, @cPalletStorerKey, '0', @cOrderKey, @cOTMCaseID, '', 0, 0, 0 , 0, 0, @cOrderKey,
                  'OTMOPC', '', @cExternOrderKey, @cConsigneeKey, @nCartonCount, '', '', '', @cOverScanMsg )
         
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 124110  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPalletFail'    
            GOTO Step_3_Fail    
         END
         
         SET @nCount = @nCount + 1 
         
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
             @cActionType = '3', 
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerKey  = @cStorerkey,
             @cOrderKey   = @cOrderKey,
             @cID         = @cPalletID,
             @cDropID     = '',
             @cRefNo1      = '',
             @cRefNo2      = @cOverScanMsg
             
      END
      
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5) ) 
      SET @cOutField04 = @nCartonCount
      SET @cOutField05 = ''

      SET @nFromStep = @nStep 
      
      -- Go to next screen
      SET @nScn = @nScn + 2
      SET @nStep = @nStep + 2
      
      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      
      
      -- Go to next screen
      SET @nScn = @nScn - 1 
      SET @nStep = @nStep - 1 
   END
   GOTO Quit
   
   Step_3_Fail:
   BEGIN
      
      SET @cOutField03 = ''
   END
END
GOTO Quit

/***********************************************************************************
Scn = 5163. screen
   PalletID       (field01)
   RefNo          (field02)
   CartonNo       (field03, input)
***********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonNo = @cInField03
      
      IF ISNULL(@cCartonNo ,'' ) = '' 
      BEGIN
         SET @nErrNo = 124111
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNoReq
         GOTO Step_4_Fail
      END
      
--      SELECT @cPickSlipNo = PickSlipNo 
--      FROM dbo.PickHeader WITH (NOLOCK) 
--      WHERE OrderKey = @cOrderKey

      
      
      SELECT @cExternOrderKey = ExternOrderKey
            ,@cConsigneeKey   = ConsigneeKey
      FROM dbo.OrderS WITH (NOLOCK) 
      WHERE StorerKey = @cPalletStorerKey
      AND OrderKey = @cOrderKey
      
      
      IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
                  WHERE CaseID = @cCartonNo   )
      BEGIN
         SET @nErrNo = 124122
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNoScanned
         GOTO Step_4_Fail
      END
      
      IF LEFT(@cCartonNo,10 ) <> @cOrderKey
      BEGIN
         SET @nErrNo = 124123
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartonNo
         GOTO Step_4_Fail
      END

      
--      SET @cCaseID = ''  
--      SET @cOTMCaseID = ''
--      SET @bSuccess = 1  
--      EXECUTE dbo.nspg_getkey  
--       'OTMCaseID'  
--       , 4  
--       , @cCaseID           OUTPUT  
--       , @bSuccess          OUTPUT  
--       , @nErrNo            OUTPUT  
--       , @cErrMsg           OUTPUT  
--       
--      IF @bSuccess <> 1  
--      BEGIN  
--         SET @nErrNo = 124113
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
--         GOTO Step_3_Fail  
--      END  
--      
--      SET @cOTMCaseID = LEFT(@cPalletID,6)  + @cCaseID
      
      -- Insert Into OTMIDTrack --
      INSERT INTO dbo.OTMIDTrack (PalletKey, Principal, MUStatus, OrderID, CaseID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume, TrackingNo,
                                 MUType, DropLoc, ExternOrderKey, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )
                               
      VALUES ( @cPalletID, @cPalletStorerKey, '0', @cOrderKey, @cCartonNo, '', 0, 0, 0 , 0, 0, @cOrderKey,
               'OTMOPC', '', @cExternOrderKey, @cConsigneeKey, @nCartonCount, '', '', '', '' )
      
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 124113  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPalletFail'    
         GOTO Step_4_Fail    
      END
      
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
          @cActionType = '3', 
          @cUserID     = @cUserName,
          @nMobileNo   = @nMobile,
          @nFunctionID = @nFunc,
          @cFacility   = @cFacility,
          @cStorerKey  = @cStorerkey,
          @cOrderKey   = @cOrderKey,
          @cID         = @cPalletID,
          @cDropID     = @cCartonNo
        
          
      
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = ''

      
      -- Go to next screen
      --SET @nScn = @nScn + 2
      --SET @nStep = @nStep + 2
      
      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

--      SELECT @nTTLPallet = Count ( CartonNo)
--      FROM dbo.PackInfo WITH (NOLOCK) 
--      WHERE PickSlipNo = @cPickSlipNo 
      
      SELECT @nTTLPallet = Count ( MUID)
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE OrderID = @cOrderKey
      AND PalletKey = @cPalletID
      AND Principal = @cPalletStorerKey  
      
      SET @nCartonCount = ''
      SELECT @nCartonCount = Count ( MUID)
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      WHERE  PalletKey = @cPalletID
      AND Principal = @cPalletStorerKey  
      
--      SET @nCartonCount = ''
--      SELECT @nCartonCount = Count ( MUID)
--      FROM dbo.OTMIDTrack WITH (NOLOCK) 
--      WHERE OrderID = @cOrderKey
--      AND PalletKey = @cPalletID
--      AND Principal = @cPalletStorerKey
      
      SET @nFromStep = @nStep 
      
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = CAST(@nTTLPallet AS NVARCHAR(5) ) 
      SET @cOutField04 = @nCartonCount
      SET @cOutField05 = ''
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit
   
   Step_4_Fail:
   BEGIN
      SET @cOutField03 = ''
      
   END
END
GOTO Quit

/***********************************************************************************
Scn = 5164. screen
   PalletID       (field01)
   RefNo          (field02)
   Total Carton   (field03)
   Total Scan     (field04)
   Option         (field05, input)
***********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField05
      
      IF ISNULL(@cOption ,'' ) = '' 
      BEGIN
         SET @nErrNo = 124114
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         GOTO Step_5_Fail
      END
      
      IF @cOption NOT IN ( '1', '5', '9','0')
      BEGIN
         SET @nErrNo = 124115
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Step_5_Fail
      END

      
      
      IF @cOption IN ( '1' , '5')
      BEGIN
--         IF @nFromStep = 3 AND @cOption <> '5'
--         BEGIN
--            SET @nErrNo = 124121
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvShortOption
--            GOTO Step_5_Fail
--         END

--         IF @cOption = '5' 
--         BEGIN
            
         
--            UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
--            SET MUStatus = '3'
--            WHERE PalletKey = @cPalletID
--            AND Principal = @cPalletStorerKey
            
--            IF @@ERROR <> 0 
--            BEGIN
--               SET @nErrNo = 124117
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdOTMIDTrackFail
--               GOTO Step_5_Fail
--            END
            
--            GOTO QUIT
            
----            SET @nCount = 0
----            
----            SELECT @cExternOrderKey = ExternOrderKey
----            ,@cConsigneeKey   = ConsigneeKey
----            FROM dbo.OrderS WITH (NOLOCK) 
----            WHERE StorerKey = @cPalletStorerKey
----            AND OrderKey = @cOrderKey
----      
----            WHILE @nCartonCount > @nCount
----            BEGIN
----               SET @cCaseID = ''  
----               SET @cOTMCaseID = ''
----               
----               SET @bSuccess = 1  
----               EXECUTE dbo.nspg_getkey  
----                'OTMCaseID'  
----                , 4  
----                , @cCaseID           OUTPUT  
----                , @bSuccess          OUTPUT  
----                , @nErrNo            OUTPUT  
----                , @cErrMsg           OUTPUT  
----                
----               IF @bSuccess <> 1  
----               BEGIN  
----                  SET @nErrNo = 124118  
----                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
----                  GOTO Step_3_Fail  
----               END  
----               
----               SET @cOTMCaseID = @cPalletID + @cCaseID
----               
----               -- Insert Into OTMIDTrack --
----               INSERT INTO dbo.OTMIDTrack (PalletKey, Principal, MUStatus, OrderID, CaseID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume, 
----                                          MUType, DropLoc, ExternOrderKey, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )
----                                        
----               VALUES ( @cPalletID, @cPalletStorerKey, '0', @cOrderKey, @cOTMCaseID, '', 0, 0, 0 , 0, 0, 
----                        'OTMOPC', '', @cExternOrderKey, @cConsigneeKey, @nCartonCount, '', '', '', 'Shorted Qty' )
----               
----               IF @@ERROR <> 0   
----               BEGIN  
----                  SET @nErrNo = 124119
----                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPalletFail'    
----                  GOTO Step_3_Fail    
----               END
----               
----               SET @nCount = @nCount + 1 
----            END   
----            
----            -- EventLog - Sign In Function
----            EXEC RDT.rdt_STD_EventLog
----             @cActionType = '3', 
----             @cUserID     = @cUserName,
----             @nMobileNo   = @nMobile,
----             @nFunctionID = @nFunc,
----             @cFacility   = @cFacility,
----             @cStorerKey  = @cStorerkey,
----             @cOrderKey   = @cOrderKey,
----             @cID         = @cPalletID,
----             @cDropID     = '',
----             @cRefNo1      = '',
----             @cRefNo2      = 'Shorted Qty'
--         END
         
         

         DECLARE @curOTMIDTrack CURSOR
         SET @curOTMIDTrack = CURSOR FOR 
         
         SELECT MUID, CaseID, TrackingNo , Principal 
         FROM dbo.OTMIDTrack WITH (NOLOCK) 
         WHERE 
         --Principal = @cPalletStorerKey
         --AND OrderID = @cOrderKey 
         PalletKey = @cPalletID
         AND MUStatus = '0' 
         
         OPEN @curOTMIDTrack
         FETCH NEXT FROM @curOTMIDTrack INTO @nMUID, @cOTMIDTrackCaseID, @cTrackingNo, @cOTMIDtrackStorerKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            

            UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
               --SET MUStatus = CASE WHEN @cOption = '1' THEN '5' ELSE '3' END
               SET MUStatus = CASE WHEN @cOption = '1' THEN '1'  END
            WHERE PalletKey = @cPalletID
            --AND Principal = @cPalletStorerKey
            AND CaseID = @cOTMIDTrackCaseID
            AND MUID  = @nMUID
            
         
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 124117
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdOTMIDTrackFail
               GOTO Step_5_Fail
            END
            
            
            IF @cOption = '1'
            BEGIN
               

--               EXEC ispGenTransmitLog 'OTMTRACKSU', @nMUID, '', @cPalletStorerKey, ''      
--                                 , @bsuccess OUTPUT      
--                                 , @nErrNo   OUTPUT      
--                                 , @cErrMsg  OUTPUT   
                          
                EXEC ispGenOTMLog 'IDTCK5OTM', @nMUID, '', @cOTMIDtrackStorerKey, '' 
               , @bsuccess OUTPUT 
               , @nErrNo OUTPUT 
               , @cErrMsg OUTPUT  
                                
                IF @bsuccess <> 1      
                BEGIN      
                     
                     SET @nErrNo = 124124      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenTLogFail  
                     GOTO Step_5_Fail
                END 
            END

            FETCH NEXT FROM @curOTMIDTrack INTO @nMUID, @cOTMIDTrackCaseID, @cTrackingNo, @cOTMIDtrackStorerKey

        END
      END
      
      
      IF @cOption = '9'
      BEGIN
         
         DELETE FROM dbo.OTMIDTrack WITH (ROWLOCK)
         WHERE PalletKey = @cPalletID
         --AND Principal = @cPalletStorerKey
         
         IF @@ERROR <> 0 
         BEGIN
           SET @nErrNo = 124116
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelOTMIDTrackFail
           GOTO Step_5_Fail
         END
         
      END
      
      IF @cOption = '0'
      BEGIN
         -- Go to next screen
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = ''
      
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3 

         GOTO QUIT
      END
      
      -- Go to next screen
      SET @cOutField01 = ''
      
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4 
      
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @nFromStep = 1 
      BEGIN
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn = @nScn - 4 
         SET @nStep = @nStep - 4 

         GOTO QUIT
      END

      IF @nFromStep = 3 
      BEGIN
--         SELECT TOP 1 @cPalletSKU = SKU 
--         FROM dbo.PickDetail  WITH (NOLOCK) 
--         WHERE OrderKey = @cOrderKey         
--         --AND DropID = @cPalletID
--         
--         SELECT @cPackKey = PackKey 
--         FROM dbo.SKU WITH (NOLOCK) 
--         WHERE StorerKey = @cPalletStorerKey
--         AND SKU = @cPalletSKU 
--         
--         SELECT @nPallet = Pallet
--               ,@nCaseCnt = CaseCnt
--         FROM dbo.Pack WITH (NOLOCK) 
--         WHERE PackKey = @cPackKey
--
--         SET @nTTLPallet =  @nPallet / @nCaseCnt
         
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = @nTTLPallet
         SET @cOutField04 = ''
      
         -- Go to next screen
         SET @nScn = @nScn - 2 
         SET @nStep = @nStep - 2 

         GOTO QUIT
      END

      IF @nFromStep = 4 
      BEGIN
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = ''
      
         -- Go to next screen
         SET @nScn = @nScn - 1 
         SET @nStep = @nStep - 1 

         GOTO QUIT
      END
   END
   GOTO Quit
   
   Step_5_Fail:
   BEGIN
      SET @cOutField05 = ''
      
      
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,
      Printer_Paper= @cPrinter_Paper,
      
	   V_String1    = @cRefNo,
      V_String2    = @cOrderKey,
      V_String3    = @cPalletStorerKey,
      V_String4    = @nFromStep,
      V_String5    = @cPalletID,
      V_String6    = @nCartonCount,
      V_String7    = @nTTLPallet,
         
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
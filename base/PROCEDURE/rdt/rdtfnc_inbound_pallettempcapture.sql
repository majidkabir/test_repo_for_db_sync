SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/
/* Store procedure: rdtfnc_Inbound_PalletTempCapture                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose:  Inbound Pallet temperature Capture                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev    Author   Purposes                                      */
/* 2024-12-05   1.0.0  NLT013   FCR-1398 Created                              */
/******************************************************************************/
        
CREATE   PROC [RDT].[rdtfnc_Inbound_PalletTempCapture](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
BEGIN
        
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- RDT.RDTMobRec variables
   DECLARE        
      @nFunc                        INT,
      @nScn                         INT,
      @nStep                        INT,
      @cLangCode                    NVARCHAR( 3),
      @nInputKey                    INT,
      @nMenu                        INT,
      @bSuccess                     INT,
      @cID                          NVARCHAR(18),
      @cReceiptKey                  NVARCHAR(10),
      @cStorerKey                   NVARCHAR( 15),
      @cUserName                    NVARCHAR( 18),
      @cFacility                    NVARCHAR( 15), 
      @cTemperature                 NVARCHAR( 7),
      @fTemperature                 DECIMAL(5, 2),
      @cASNStatus                   NVARCHAR(10),
      @cASNSCanctatus               NVARCHAR(10),
      @nRowCount                    INT,
      @cStorerGroup                 NVARCHAR( 20),
      @cTempScale                   NVARCHAR( 5),
      @cItemClass                   NVARCHAR(10),
      @fLowerTemp                   DECIMAL(5, 2),
      @fHigherTemp                  DECIMAL(5, 2),
      @cScale                       NVARCHAR(5),
      @cUDF04                       NVARCHAR(10),
      @cOption                      NVARCHAR(1),
      
      @nStep_ASN                    INT,
      @nStep_ID                     INT,
      @nStep_Temperature            INT,
      @nStep_Confrim                INT,
      @nScn_ASN                     INT,
      @nScn_ID                      INT,
      @nScn_temperature             INT,
      @nScn_Confrim                 INT,

      @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),  @cLottable01  NVARCHAR( 18),
      @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),  @cLottable02  NVARCHAR( 18),
      @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),  @cLottable03  NVARCHAR( 18),
      @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),  @dLottable04  DATETIME,
      @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),  @dLottable05  DATETIME,
      @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),  @cLottable06  NVARCHAR( 30),
      @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),  @cLottable07  NVARCHAR( 30),
      @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),  @cLottable08  NVARCHAR( 30),
      @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),  @cLottable09  NVARCHAR( 30),
      @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),  @cLottable10  NVARCHAR( 30),
      @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),  @cLottable11  NVARCHAR( 30),
      @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),  @cLottable12  NVARCHAR( 30),
      @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),  @dLottable13  DATETIME,
      @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),  @dLottable14  DATETIME,
      @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1),  @dLottable15  DATETIME,

      @cExtScnUDF01  NVARCHAR( 250), @cExtScnUDF02 NVARCHAR( 250), @cExtScnUDF03 NVARCHAR( 250),
      @cExtScnUDF04  NVARCHAR( 250), @cExtScnUDF05 NVARCHAR( 250), @cExtScnUDF06 NVARCHAR( 250),
      @cExtScnUDF07  NVARCHAR( 250), @cExtScnUDF08 NVARCHAR( 250), @cExtScnUDF09 NVARCHAR( 250),
      @cExtScnUDF10  NVARCHAR( 250), @cExtScnUDF11 NVARCHAR( 250), @cExtScnUDF12 NVARCHAR( 250),
      @cExtScnUDF13  NVARCHAR( 250), @cExtScnUDF14 NVARCHAR( 250), @cExtScnUDF15 NVARCHAR( 250),
      @cExtScnUDF16  NVARCHAR( 250), @cExtScnUDF17 NVARCHAR( 250), @cExtScnUDF18 NVARCHAR( 250),
      @cExtScnUDF19  NVARCHAR( 250), @cExtScnUDF20 NVARCHAR( 250), @cExtScnUDF21 NVARCHAR( 250),
      @cExtScnUDF22  NVARCHAR( 250), @cExtScnUDF23 NVARCHAR( 250), @cExtScnUDF24 NVARCHAR( 250),
      @cExtScnUDF25  NVARCHAR( 250), @cExtScnUDF26 NVARCHAR( 250), @cExtScnUDF27 NVARCHAR( 250),
      @cExtScnUDF28  NVARCHAR( 250), @cExtScnUDF29 NVARCHAR( 250), @cExtScnUDF30 NVARCHAR( 250)

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
      @cReceiptKey      = V_ReceiptKey,
      @cID              = V_ID,
      @cStorerGroup     = StorerGroup, 

      @fTemperature     = TRY_CAST(V_String1 AS DECIMAL(5, 2)),
      @cTempScale       = V_String2,
      @fLowerTemp       = TRY_CAST(V_String3 AS DECIMAL(5, 2)),
      @fHigherTemp      = TRY_CAST(V_String4 AS DECIMAL(5, 2)),

      @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
      @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
      @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
      @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
      @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
      @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
      @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
      @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
      @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
      @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
      @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
      @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
      @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
      @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
      @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15 
            
   FROM rdt.rdtMobRec WITH (NOLOCK)        
   WHERE Mobile = @nMobile

   SELECT        
      @nStep_ASN              = 1,  @nScn_ASN            = 6530,
      @nStep_ID               = 2,  @nScn_ID             = 6531,
      @nStep_Temperature      = 3,  @nScn_temperature    = 6532,
      @nStep_Confrim          = 4,  @nScn_Confrim        = 6533


   IF @nFunc = 1869
   BEGIN        
      -- Redirect to respective screen        
      IF @nStep = 0  GOTO Step_0                -- Menu. Func = 1869
      IF @nStep = 1  GOTO Step_1                -- Scn = 6530. Scan ASN
      IF @nStep = 2  GOTO Step_2                -- Scn = 6531. Scan ID
      IF @nStep = 3  GOTO Step_3                -- Scn = 6532. Capture temperature
      IF @nStep = 4  GOTO Step_4                -- Scn = 6533. Confrim option
   END        
         
   RETURN -- Do nothing if incorrect step   

   Step_0:
   BEGIN
      -- Prepare next screen var        
      SET @cOutField01 = ''     
         
      EXEC rdt.rdtSetFocusField @nMobile, 1          
            
      -- Logging        
      EXEC RDT.rdt_STD_EventLog        
         @cActionType     = '1', -- Sign-in        
         @cUserID         = @cUserName,        
         @nMobileNo       = @nMobile,        
         @nFunctionID     = @nFunc,        
         @cFacility       = @cFacility,        
         @cStorerKey      = @cStorerKey,        
         @nStep           = @nStep        
         
      -- Go to next screen        
      SET @nScn = @nScn_ASN        
      SET @nStep = @nStep_ASN

   END  
   GOTO Quit


   /************************************************************************************
   Step 1 Scn = 6530. Scan ASN        
      ASN         (field01, input)               
   ************************************************************************************/
   Step_1:
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cReceiptKey = @cInField01

         DECLARE 
            @cASNFacility        NVARCHAR(15),
            @cASNStorerKey       NVARCHAR(15)

         IF @cReceiptKey = ''
         BEGIN
            SET @nErrNo = 230201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNIsNeeded
            GOTO Step_1_Fail
         END

         SELECT @cASNStatus   = Status,
            @cASNSCanctatus   = ASNStatus,
            @cASNFacility     = ISNULL(Facility, ''),
            @cASNStorerKey    = StorerKey
         FROM dbo.Receipt WITH(NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         
         SELECT @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 230202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNNotExist
            GOTO Step_1_Fail
         END

         IF @cASNFacility <> @cFacility
         BEGIN
            SET @nErrNo = 230203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffFacility
            GOTO Step_1_Fail
         END

         IF @cASNStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 230204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffStorer
            GOTO Step_1_Fail
         END

         IF @cStorerGroup <> ''
         BEGIN
            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cASNStorerKey)
            BEGIN
               SET @nErrNo = 230205
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               GOTO Step_1_Fail
            END
         END

         IF @cASNStatus = '9'
         BEGIN
            SET @nErrNo = 230206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNClosed
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF @cASNSCanctatus = 'CANC'
         BEGIN
            SET @nErrNo = 230207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASNCancelled
            GOTO Step_1_Fail
         END

         SET @cOutField01 = @cReceiptKey  --ASN
         SET @cOutField02 = ''            --ID

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      IF @nInputKey = 0 -- ESC
      BEGIN
         -- EventLog - Sign Out Function
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign Out function
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
      END
      GOTO Quit

      Step_1_Fail:
      BEGIN
         SET @cOutField01 = '' --ASN
         SET @cReceiptKey = '' --ASN
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         GOTO Quit
      END
   END
   

   /************************************************************************************
   Step 2. Scn = 6531. Scan Id
      ASN         (field01)
      ID          (field02, input)
   ************************************************************************************/
   Step_2:
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cID = @cInField02

         IF @cID = ''
         BEGIN
            SET @nErrNo = 230208
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDIsNeeded
            GOTO Step_2_Fail
         END

         IF NOT EXISTS(
            SELECT 1 FROM dbo.RECEIPTDETAIL WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey AND ToID = @cID
         )
         BEGIN
            SET @nErrNo = 230209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --30209ID does not exist in ASN
            GOTO Step_2_Fail
         END

         SELECT @nRowCount = COUNT(DISTINCT SKU)
         FROM dbo.RECEIPTDETAIL WITH(NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND ToID = @cID

         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 230210
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --230210Multiple SKU in the ID
            GOTO Step_2_Fail
         END

         SELECT TOP 1 @cItemClass = ItemClass
         FROM dbo.SKU WITH(NOLOCK)
         INNER JOIN dbo.RECEIPTDETAIL RP WITH(NOLOCK)
            ON SKU.StorerKey = RP.StorerKey
            AND SKU.Sku = RP.Sku
         WHERE SKU.StorerKey = @cStorerKey
            AND RP.ToID = @cID

         IF @cItemClass IS NULL OR @cItemClass = ''
         BEGIN
            SET @nErrNo = 230213
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoItemClass
            GOTO Step_2_Fail
         END

         SELECT @fLowerTemp = TRY_CAST(UDF01 AS DECIMAL(5, 2)),
            @fHigherTemp = TRY_CAST(UDF02 AS DECIMAL(5, 2)),
            @cScale = CASE UDF03 
                        WHEN 'Celcius' THEN '°C'
                        WHEN 'Fahrenheit' THEN '°F'
                        ELSE ''
                     END,
            @cUDF04 = UDF04
         FROM dbo.CODELKUP WITH(NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LISTNAME = 'ITEMCLASS'
            AND Code = @cItemClass
         ORDER BY UDF04

         SELECT @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 230214
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MissCodeList
            GOTO Step_2_Fail
         END

         IF @fLowerTemp IS NULL OR @fHigherTemp IS NULL OR ISNULL(@cScale, '') = '' OR @fLowerTemp > @fHigherTemp OR ISNULL(@cUDF04, '') NOT IN ('BOTH', 'RCV')
         BEGIN
            SET @nErrNo = 230215
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --230215Item class code needs to be maintained properly
            GOTO Step_2_Fail
         END

         SET @cOutField01 = @cReceiptKey  --ASN
         SET @cOutField02 = @cID          --ID
         SET @cOutField03 = ''            --Temp
         SET @cOutField04 = @cScale       --Temp Scale
         

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      IF @nInputKey = 0 -- ESC
      BEGIN
         --prepare prev screen variable
         SET @cReceiptKey = ''

         SET @cOutField01 = ''

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      GOTO Quit

      Step_2_Fail:
      BEGIN
         SET @cOutField01 = @cReceiptKey  --ASN
         SET @cOutField02 = ''            --ID
         SET @cOutField03 = ''            --Temp
         SET @cOutField04 = @cScale       --Temp Scale

         SET @cID = ''                    --ID
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID
         GOTO Quit
      END
   END

   /************************************************************************************
   Step 3. Scn = 6532. Scan Temp
      ASN         (field01)
      ID          (field02)
      Temp        (field03, input)
   ************************************************************************************/
   Step_3:
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cTemperature = @cInField03

         IF @cTemperature = ''
         BEGIN
            SET @nErrNo = 230211
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TempIsNeeded
            GOTO Step_3_Fail
         END

         SET @fTemperature = TRY_CAST(@cTemperature AS DECIMAL(5,2))

         IF @fTemperature IS NULL
         BEGIN
            SET @nErrNo = 230212
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --230212Temp is not numeric
            GOTO Step_3_Fail
         END

         IF @fTemperature < @fLowerTemp OR @fTemperature > @fHigherTemp
         BEGIN
            --prepare prev screen variable
            SET @cOutField01 = @cTemperature  --temperature
            SET @cOutField02 = ''            --Option

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
         ELSE
         BEGIN
            BEGIN TRY
               EXEC rdt.rdt_Inbound_IDTempCap_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
                  @cReceiptKey,
                  @cID,
                  @fTemperature,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END TRY
            BEGIN CATCH
               SET @nErrNo = 230216
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --230216Capture temperature fail
               GOTO Step_3_Fail
            END CATCH

            --prepare prev screen variable
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1

         END
      END

      IF @nInputKey = 0 -- ESC
      BEGIN
         --prepare prev screen variable
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      GOTO Quit

      Step_3_Fail:
      BEGIN
         SET @cOutField01 = @cReceiptKey  --ASN
         SET @cOutField02 = @cID          --ID
         SET @cOutField03 = ''            --Temp

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

         GOTO Quit
      END
   END

   /************************************************************************************
   Step 4. Scn = 6533. Scan Confirm Exceeded Temperature
      Temp        (field01)
      Option      (field02, input)
   ************************************************************************************/
   Step_4:
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cOption = @cInField02

         IF @cOption = ''
         BEGIN
            SET @nErrNo = 230217
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionIsNeeded
            GOTO Step_4_Fail
         END

         IF @cOption NOT IN ('1', '9')
         BEGIN
            SET @nErrNo = 230218
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
            GOTO Step_4_Fail
         END

         IF @cOption = '1'
         BEGIN
            BEGIN TRY
               EXEC rdt.rdt_Inbound_IDTempCap_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
                  @cReceiptKey,
                  @cID,
                  @fTemperature,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END TRY
            BEGIN CATCH
               SET @nErrNo = 230219
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --230216Capture temperature fail
               GOTO Step_3_Fail
            END CATCH

            --prepare prev screen variable
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE IF @cOption = '9'
         BEGIN
            SET @cOutField01 = @cReceiptKey  --ASN
            SET @cOutField02 = @cID          --ID
            SET @cOutField03 = ''            --Temp

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
      END

      IF @nInputKey = 0 -- ESC
      BEGIN
         --prepare prev screen variable
         SET @cOutField01 = @cReceiptKey  --ASN
         SET @cOutField02 = @cID          --ID
         SET @cOutField03 = ''            --Temp
         SET @cOutField04 = @cScale       --Temp Scale

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      GOTO Quit

      Step_4_Fail:
      BEGIN
         SET @cOutField01 = @fTemperature  --Temperature
         SET @cOutField02 = ''            --Option

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID

         GOTO Quit
      END
   END

   
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
         
         V_ReceiptKey      = @cReceiptKey,
         V_ID              = @cID,

         V_String1 = TRY_CAST(@fTemperature AS NVARCHAR(7)),
         V_String2 = @cTempScale,
         V_String3 = TRY_CAST(@fLowerTemp AS NVARCHAR(7)),
         V_String4 = TRY_CAST(@fHigherTemp AS NVARCHAR(7)),
            
         I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
         I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
         I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
         I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
         I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
         I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
         I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
         I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
         I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
         I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
         I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
         I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
         I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
         I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
         I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15
      WHERE Mobile = @nMobile
   END

END

GO
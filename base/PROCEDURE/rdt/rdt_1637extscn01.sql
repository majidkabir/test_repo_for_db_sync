SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1637ExtScn01                                    */  
/*                                                                      */  
/* Customer: Inditex                                                    */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-08-15 1.0  NLT013     FCR-673. Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1637ExtScn01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep INT,           
   @nScn  INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData   VariableTable READONLY,

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 2. Prepare output fields, Step = 99 is a new screen
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nRowCount                 INT,
      @cExtendedUpdateSP         NVARCHAR(20),
      @cExtendedValidateSP       NVARCHAR(20),
      @cExtendedInfoSP           NVARCHAR(20),

      @cContainerKey             NVARCHAR(10),
      @cContainerNo              NVARCHAR(20),
      @cNewKey                   NVARCHAR(20),
      @cContainerStatus          NVARCHAR(10),
      @cUserName                 NVARCHAR(18),
      @bSuccess                  INT,
      @nTranCount                INT,
      @nMenu                     INT,  
      @cMBOLKEY                  NVARCHAR(10),
      @cScanCnt                  NVARCHAR(5),
      @cTotalCnt                 NVARCHAR(5),
      @cDefaultContainerType     NVARCHAR(10),
      @cOrderKey                 NVARCHAR(10)

   SET @nErrNo = 0

   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SELECT
      @nMenu = Menu,
      @cUserName = UserName
   FROM RDTMOBREC (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 1637
   BEGIN
      IF @nAction = 0
      BEGIN
         IF @nStep = 1 AND @nScn = 2190
         BEGIN
            SET @nAfterScn = 6418
            SET @nAfterStep = 99

            SET @cUDF01 = '' -- @cContainerKey
            SET @cUDF02 = '' -- @cMBOLKEY
            SET @cUDF03 = '' -- @cContainerNo
            SET @cUDF04 = '' -- @cScanCnt
            SET @cUDF05 = '' -- @cTotalCTNCnt
            SET @cUDF06 = '' -- Func
            SET @cUDF30 = 'UPDATE' -- UPDATE Flag

            SET @cOutField01 = ''  
            SET @cOutField02 = ''  

            EXEC rdt.rdtSetFocusField @nMobile, 2
         END 

         GOTO Quit
      END

      IF @nStep = 99
      BEGIN
         IF @nScn = 6418
         BEGIN
            IF @nInputKey = 1 -- ENTER  
            BEGIN  
               -- Screen mapping  
               SET @cContainerKey = @cInField01  
               SET @cContainerNo = @cInField02  

               IF @cContainerNo IS NULL OR TRIM(@cContainerNo) = ''
               BEGIN
                  SET @nErrNo = 221351  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ContainerNoIsNeeded
                  GOTO Fail
               END

               SELECT @cOrderKey = OrderKey
               FROM dbo.ORDERS WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ExternOrderKey = @cContainerNo
                  AND Status NOT IN ('9', 'CANC')

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
               BEGIN
                  SET @nErrNo = 221352
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidContainerNo
                  GOTO Fail
               END

               SELECT @cMBOLKEY = MBOLD.MBolKey
               FROM dbo.MBOLDETAIL MBOLD WITH (NOLOCK)
               INNER JOIN dbo.PICKDETAIL pkd WITH(NOLOCK) ON MBOLD.OrderKey = pkd.OrderKey
               WHERE pkd.OrderKey = @cOrderKey
                  AND pkd.StorerKey = @cStorerKey

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0 OR @cMBOLKEY IS NULL OR TRIM(@cMBOLKEY) = ''
               BEGIN  
                  SET @nErrNo = 221353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMBolKey
                  GOTO Fail
               END

               SELECT @cTotalCnt = CAST(COUNT(DISTINCT pkd.ID) AS NVARCHAR(5))
               FROM dbo.MBOLDETAIL MBOLD WITH (NOLOCK)
               INNER JOIN dbo.PICKDETAIL pkd WITH(NOLOCK) ON MBOLD.OrderKey = pkd.OrderKey
               WHERE MBOLD.MBolKey = @cMBOLKEY
                  AND pkd.StorerKey = @cStorerKey
                  AND pkd.Status NOT IN ('4', '9')

               SET @cTotalCnt = IIF(@cTotalCnt IS NULL, '0', @cTotalCnt)

               SELECT
                  @cContainerKey = ContainerKey
               FROM dbo.Container WITH(NOLOCK)
               WHERE ISNULL(BookingReference, '') = @cContainerNo

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount > 0 AND TRIM(@cContainerKey) <> '' 
               BEGIN
                  IF EXISTS (SELECT 1 FROM dbo.CONTAINER WITH (NOLOCK) WHERE ContainerKey = @cContainerKey AND Status > 0)
                  BEGIN
                     SET @nErrNo = 221354
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Container is Closed
                     GOTO Fail
                  END
                  ELSE
                  BEGIN
                     SELECT @cScanCnt = CAST(COUNT(DISTINCT PalletKey) AS NVARCHAR(10))
                     FROM dbo.CONTAINERDETAIL WITH (NOLOCK)
                     WHERE ContainerKey = @cContainerKey

                     --prepare next screen variable  
                     SET @cOutField01 = @cContainerKey
                     SET @cOutField02 = @cMBOLKEY
                     SET @cOutField03 = @cContainerNo
                     SET @cOutField04 = ''  
                     SET @cOutField05 = @cScanCnt
                     SET @cOutField06 = 'Total:' + ISNULL(TRY_CAST(@cTotalCnt AS NVARCHAR(5)), '0')
            
                     SET @cUDF01 = @cContainerKey
                     SET @cUDF02 = @cMBOLKEY
                     SET @cUDF03 = @cContainerNo
                     SET @cUDF04 = @cScanCnt
                     SET @cUDF05 = @cTotalCnt
                     SET @cUDF30 = 'UPDATE' -- UPDATE Flag

                     SET @nAfterScn = 2192
                     SET @nAfterStep = 3
                     GOTO Quit
                  END
               END

               --The Container does not exists, create a container
               SET @cDefaultContainerType = rdt.RDTGetConfig( @nFunc, 'DefaultContainerType', @cStorerkey)  
               IF @cDefaultContainerType = '0'
                  SET @cDefaultContainerType = ''
                  
               SET @nTranCount = @@TRANCOUNT

               IF @nTranCount = 0
                  BEGIN TRANSACTION
               ELSE
                  SAVE TRANSACTION rdt_1637ExtScn01_6418
               
               BEGIN TRY
                  EXECUTE nspg_getkey
                     'ContainerKey'
                     , 10
                     , @cNewKey          OUTPUT
                     , @bSuccess         OUTPUT
                     , @nErrNo           OUTPUT
                     , @cErrMsg          OUTPUT

                  IF @bSuccess <> 1
                  BEGIN
                     IF @@TRANCOUNT > @nTranCount AND @@TRANCOUNT > 0
                        ROLLBACK TRANSACTION rdt_1637ExtScn01_6418
                     ELSE
                        ROLLBACK TRANSACTION

                     SET @nErrNo = 221355
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Generate Key Failed
                     GOTO Quit
                  END

                  SET @cContainerKey = @cNewKey

                  -- Insert new container
                  INSERT INTO dbo.Container
                     (ContainerKey, Status, ContainerType, BookingReference, MBolKey) 
                  VALUES 
                     (@cNewKey, '0', @cDefaultContainerType, @cContainerNo, @cMBOLKEY)  

                  IF @@ERROR <> 0  
                  BEGIN
                     IF @@TRANCOUNT > @nTranCount AND @@TRANCOUNT > 0
                        ROLLBACK TRANSACTION rdt_1637ExtScn01_6418
                     ELSE
                        ROLLBACK TRANSACTION

                     SET @nErrNo = 221356
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert Container Failed
                     GOTO Quit
                  END

                  IF @@TRANCOUNT > @nTranCount
                     COMMIT TRANSACTION
               END TRY
               BEGIN CATCH
                  IF @nTranCount = 0
                  BEGIN
                     ROLLBACK TRANSACTION
                  END
                  ELSE
                  BEGIN
                     IF XACT_STATE() <> -1
                     BEGIN
                        ROLLBACK TRANSACTION rdt_1637ExtScn01_6418
                     END
                  END

                  SET @nErrNo = 221357
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exception Happens
                  GOTO Quit
               END CATCH

               SET @cScanCnt = '0'

               --prepare next screen variable  
               SET @cOutField01 = @cContainerKey
               SET @cOutField02 = @cMBOLKEY
               SET @cOutField03 = @cContainerNo
               SET @cOutField04 = ''  
               SET @cOutField05 = @cScanCnt
               SET @cOutField06 = 'Total:' + ISNULL(TRY_CAST(@cTotalCnt AS NVARCHAR(5)), '0')
      
               SET @cUDF01 = @cContainerKey
               SET @cUDF02 = @cMBOLKEY
               SET @cUDF03 = @cContainerNo
               SET @cUDF04 = @cScanCnt
               SET @cUDF05 = @cTotalCnt
               SET @cUDF30 = 'UPDATE' -- UPDATE Flag

               SET @nAfterScn = 2192
               SET @nAfterStep = 3
               GOTO Quit
            END  
         
            IF @nInputKey = 0 -- ESC  
            BEGIN  
               --eventLog  --(cc01)
               EXEC RDT.rdt_STD_EventLog
                  @cActionType = '9', -- Sign Out function
                  @cUserID     = @cUserName,
                  @nMobileNo   = @nMobile,
                  @nFunctionID = @nFunc,
                  @cFacility   = @cFacility,
                  @cStorerKey  = @cStorerkey
         
               SET @cOutField01 = ''  
               SET @cOutField02 = ''  
               SET @cOutField03 = ''  
               SET @cOutField04 = ''  
         
               SET @cUDF01 = '' -- @cContainerKey
               SET @cUDF02 = '' -- @cMBOLKEY
               SET @cUDF03 = '' -- @cContainerNo
               SET @cUDF04 = '' -- @cScanCnt
               SET @cUDF04 = '' -- @cTotalCTNCnt
               SET @cUDF05 = '' -- @cContaincTotalCnterNo
               SET @cUDF06 = 'BACKTOMENU'    --Back to Menu
               SET @cUDF30 = 'UPDATE' -- UPDATE Flag
            END  
            GOTO Quit
         END
      END
   END

   GOTO Quit
Fail:
   SET @cUDF01 = '' -- @cContainerKey
   SET @cUDF02 = '' -- @cMBOLKEY
   SET @cUDF03 = '' -- @cContainerNo
   SET @cUDF04 = '' -- @cScanCnt
   SET @cUDF04 = '' -- @cTotalCTNCnt
   SET @cUDF05 = '' -- @cContaincTotalCnterNo
   SET @cUDF30 = 'UPDATE' -- UPDATE Flag

   SET @cOutField01 = ''  
   SET @cOutField02 = ''  

   EXEC rdt.rdtSetFocusField @nMobile, 2
Quit:
END

GO
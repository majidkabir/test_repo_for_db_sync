SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ScanIn                                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Scan In                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2021-08-02   1.0  James      WMS-17632. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ScanIn](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

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

   @cPickslipNo    NVARCHAR( 10),
   @cPickerID      NVARCHAR( 20),
   @cStatus        NVARCHAR( 1),
   @cZone          NVARCHAR( 18),
   @cOWITF         NVARCHAR( 1),
   @cPICK_TRF      NVARCHAR( 1),
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 20),

   @cAllowScanOutPKSlipStatus4 NVARCHAR( 1),
   @cActualStorer   NVARCHAR( 15), 
   @cLoadKey        NVARCHAR( 10), 
   @cActualFacility NVARCHAR(  5), 
   @cOrderKey       NVARCHAR( 10), 
   @cWaveKey        NVARCHAR( 10), 

   @nTranCount      INT,           
   @cSQL            NVARCHAR(1000),
   @cSQLParam       NVARCHAR(1000),
   @cExtendedValidateSP    NVARCHAR(20),
   @cExtendedUpdateSP      NVARCHAR(20),
   @cExtendedInfoSP        NVARCHAR(20),

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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
   @cPickslipNo      = V_PickSlipNo,
    
   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cPickerID           = V_String4,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE 
   @nStep_ScanIn INT,  @nScn_ScanIn INT

SELECT
   @nStep_ScanIn = 1,  @nScn_ScanIn = 5950


IF @nFunc = 1589
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start   -- Menu. Func = 1589
   IF @nStep = 1  GOTO Step_ScanIn  -- Scn = 5950 Scan In
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1589
********************************************************************************/
Step_Start:
BEGIN
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
      
   SET @cPickslipNo = ''
   SET @cPickerID = ''
   
   -- Prepare next screen var
   SET @cOutField01 = '' -- Pickslip No
   SET @cOutField02 = '' -- Picker Id

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

   -- Go to Scan In screen
   SET @nScn = @nScn_ScanIn
   SET @nStep = @nStep_ScanIn

END
GOTO Quit


/********************************************************************************
Scn = 1780. Pickslip screen
   Pickslip (field01, input)
********************************************************************************/
Step_ScanIn:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       SET @cPickslipNo = @cInField01
       SET @cPickerID = @cInField02

		--if pickslip blank
		IF ISNULL(@cPickslipNo, '') = ''
		BEGIN			
	      SET @nErrNo = 172601
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pkslip needed
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickerID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
	      GOTO Quit
		END

      -- Check if exists in pickheader table
      IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickslipNo)
		BEGIN			
	      SET @nErrNo = 172602
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PKSlip
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickerID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
	      GOTO Quit
		END

      IF EXISTS (SELECT 1 
                 FROM dbo.PickingInfo WITH (NOLOCK) 
                 WHERE PickSlipNo = @cPickslipNo
                 AND ScanInDate IS NOT NULL)
		BEGIN			
	      SET @nErrNo = 172603
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scanned in
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickerID
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
	      GOTO Quit
		END
      
      IF @cPickerID = ''
		BEGIN			
	      SET @nErrNo = 172604
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickedId
         SET @cOutField01 = @cPickslipNo
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Picker Id
	      GOTO Quit
		END
      
      SELECT @cLoadkey = ExternOrderkey, 
             @cOrderKey = OrderKey,       
             @cWaveKey = Wavekey 
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickslipNo

      IF ISNULL( @cOrderKey, '') <> ''    
      BEGIN
         SELECT TOP 1 @cActualStorer = Storerkey,
                      @cActualFacility = Facility
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE Orderkey = @cOrderKey
         ORDER BY 1
      END
      ELSE
      IF ISNULL( @cLoadkey, '') <> ''
      BEGIN
         SELECT TOP 1 @cActualStorer = ORD.Storerkey,
                      @cActualFacility = ORD.Facility
         FROM dbo.ORDERS ORD WITH (NOLOCK)
         JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = ORD.Orderkey)
         WHERE LPD.Loadkey = @cLoadkey
         ORDER BY 1
      END
      ELSE
      IF ISNULL( @cWaveKey, '') <> ''     
      BEGIN
         SELECT TOP 1 @cActualStorer = Storerkey,
                      @cActualFacility = Facility
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE Userdefine09 = @cWaveKey
         AND   (( ISNULL( @cOrderKey, '') = '') OR (OrderKey = @cOrderKey))
         ORDER BY 1
      END

      IF @cActualStorer <> @cStorerkey
      BEGIN
	      SET @nErrNo = 172605
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
	      GOTO ScanIn_Fail
      END

      IF @cActualFacility <> @cFacility
      BEGIN
	      SET @nErrNo = 172606
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
	      GOTO ScanIn_Fail
      END

      -- Check if orders already shipped
      IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   (( ISNULL( @cOrderKey, '') = '') OR (OrderKey = @cOrderKey))
                  AND   (( ISNULL( @cLoadKey, '') = '') OR (LoadKey = @cLoadKey))
                  AND   (( ISNULL( @cWaveKey, '') = '') OR (UserDefine09 = @cWaveKey))
                  AND   [Status] = '9')
   	BEGIN			
   	   SET @nErrNo = 172607
   	   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
	      GOTO ScanIn_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslipNo, @cPickerID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     + 
               '@nInputKey    INT,       '     +
               '@cStorerKey   NVARCHAR( 15), ' + 
               '@cPickslipNo  NVARCHAR( 10), ' + 
               '@cPickerID    NVARCHAR( 20), ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslipNo, @cPickerID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
	            GOTO ScanIn_Fail
         END
      END
      
      -- Scan in Start
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN    
      SAVE TRAN ScanIn

      SET @nErrNo = 0
      EXEC dbo.isp_ScanInPickslip
	      @c_PickSlipNo 		= @cPickslipNo, 
         @c_PickerID       = @cPickerID,  
	      @n_err            = @nErrNo OUTPUT,
	      @c_errmsg         = @cErrMsg OUTPUT          
	      
	   IF @nErrNo <> 0
      BEGIN
	      SET @nErrNo = 172608
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanOutFail     
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
         GOTO RollBackTran
      END   

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslipNo, @cPickerID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     + 
               '@nInputKey    INT,       '     +
               '@cStorerKey   NVARCHAR( 15), ' + 
               '@cPickslipNo  NVARCHAR( 10), ' + 
               '@cPickerID    NVARCHAR( 20), ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslipNo, @cPickerID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
	            GOTO RollBackTran
         END
      END
      
      GOTO ScanInEnd
      
      RollBackTran:  
         ROLLBACK TRAN ScanIn -- Only rollback change made here  

      ScanInEnd:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
      -- Scan In End

      SET @cErrMsg = SUBSTRING( rdt.rdtgetmessage( 172609, @cLangCode, 'DSP'), 8, 13) --'ScanInSuccess'
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
   END
   GOTO Quit

   ScanIn_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Pickslip No
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
      Printer      = @cPrinter,    
      V_PickSlipNo = @cPickslipNo,
    
      V_String1 = @cExtendedUpdateSP,
      V_String2 = @cExtendedValidateSP,
      V_String3 = @cExtendedInfoSP,
      V_String4 = @cPickerID,
         
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15
   WHERE Mobile = @nMobile
END


SET QUOTED_IDENTIFIER OFF

GO
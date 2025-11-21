SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ScanOut                                      */
/* Copyright      : IDS                                                 */
/* FBR: 112806                                                          */
/* Purpose: RDT Scan Out                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 31-Jul-2008  1.0  James      Created                                 */
/* 26-Mar-2009  1.1  James      SOS132566 - Add in checking for         */
/*                              'AllowScanOutPKSlipStatus4'             */
/* 09-Jul-2009  1.2  Vicky      SOS#141306 - Add Storer & Facility      */
/*                              Validation (Vicky01)                    */
/* 20-May-2014  1.3  James      SOS311616 - Allow storerkey to be       */
/*                              retrieved by different PS type (james01)*/
/* 21-May-2014  1.4  James      SOS303019 - Add extended validate SP    */
/*                              (james02)                               */
/* 30-Sep-2016  1.5  Ung        Performance tuning                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ScanOut](
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

   @cPickslip      NVARCHAR( 20),
   @cStatus        NVARCHAR( 1),
   @cZone          NVARCHAR( 18),
   @cOWITF         NVARCHAR( 1),
   @cPICK_TRF      NVARCHAR( 1),
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 20),
   -- SOS132566
   @cAllowScanOutPKSlipStatus4 NVARCHAR( 1),
   @cActualStorer   NVARCHAR( 15), -- (Vicky01)
   @cLoadKey        NVARCHAR( 10), -- (Vicky01)
   @cActualFacility NVARCHAR(  5), -- (Vicky01)
   @cOrderKey       NVARCHAR( 10), -- (james01)
   @cWaveKey        NVARCHAR( 10), -- (james01)

   @nValid          INT,                     -- (james02)
   @cSQL            NVARCHAR(1000),          -- (james02)
   @cSQLParam       NVARCHAR(1000),          -- (james02)
   @cExtendedValidateSP     NVARCHAR(20),    -- (james02)


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
   @nStep_ScanOut INT,  @nScn_ScanOut INT

SELECT
   @nStep_ScanOut = 1,  @nScn_ScanOut = 1780


IF @nFunc = 1590
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start   -- Menu. Func = 1590
   IF @nStep = 1  GOTO Step_ScanOut -- Scn = 1780 ScanOut
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1590
********************************************************************************/
Step_Start:
BEGIN

   -- Prepare next screen var
   SET @cOutField01 = '' -- Label No

   -- Go to ParentSKU screen
   SET @nScn = @nScn_ScanOut
   SET @nStep = @nStep_ScanOut
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
   END
END
GOTO Quit


/********************************************************************************
Scn = 1780. Pickslip screen
   Pickslip (field01, input)
********************************************************************************/
Step_ScanOut:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       SET @cPickslip = @cInField01

		--if pickslip blank
		IF ISNULL(@cPickslip, '') = ''
		BEGIN			
	      SET @nErrNo = 65701
	      SET @cErrMsg = rdt.rdtgetmessage( 65701, @cLangCode, 'DSP') --Pkslip needed
	      GOTO ScanOut_Fail
		END

      -- Check if exists in pickheader table
      IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickslip)
		BEGIN			
	      SET @nErrNo = 65702
	      SET @cErrMsg = rdt.rdtgetmessage( 65702, @cLangCode, 'DSP') --Invalid PKSlip
	      GOTO ScanOut_Fail
		END

      -- (Vicky01) - Start
      SELECT @cLoadkey = ExternOrderkey, 
             @cOrderKey = OrderKey,       -- (james01)
             @cWaveKey = Wavekey 
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickslip

      IF ISNULL( @cLoadkey, '') <> ''
      BEGIN
         SELECT TOP 1 @cActualStorer = ORD.Storerkey,
                      @cActualFacility = ORD.Facility
         FROM dbo.ORDERS ORD WITH (NOLOCK)
         JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = ORD.Orderkey)
         WHERE LPD.Loadkey = @cLoadkey
      END
      ELSE
      IF ISNULL( @cOrderKey, '') <> ''    -- (james01)
      BEGIN
         SELECT TOP 1 @cActualStorer = Storerkey,
                      @cActualFacility = Facility
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE Orderkey = @cOrderKey
      END
      ELSE
      IF ISNULL( @cWaveKey, '') <> ''     -- (james01)
      BEGIN
         SELECT TOP 1 @cActualStorer = Storerkey,
                      @cActualFacility = Facility
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE Userdefine09 = @cWaveKey
         AND   OrderKey = CASE WHEN ISNULL( @cOrderKey, '') <> '' THEN @cOrderKey ELSE OrderKey END
      END

      IF @cActualStorer <> @cStorerkey
      BEGIN
	      SET @nErrNo = 65715
	      SET @cErrMsg = rdt.rdtgetmessage( 65715, @cLangCode, 'DSP') --Diff Storer
	      GOTO ScanOut_Fail
      END

      IF @cActualFacility <> @cFacility
      BEGIN
	      SET @nErrNo = 65716
	      SET @cErrMsg = rdt.rdtgetmessage( 65716, @cLangCode, 'DSP') --Diff Facility
	      GOTO ScanOut_Fail
      END
      -- (Vicky01) - End


      -- Check if already scan in		
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickslip
            AND ScanInDate IS NOT NULL)
		BEGIN			
	      SET @nErrNo = 65703
	      SET @cErrMsg = rdt.rdtgetmessage( 65703, @cLangCode, 'DSP') --PS NotScanIn
	      GOTO ScanOut_Fail
		END

      -- Check if already scan in		
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickslip
            AND ScanOutDate IS NULL)
		BEGIN			
	      SET @nErrNo = 65704
	      SET @cErrMsg = rdt.rdtgetmessage( 65704, @cLangCode, 'DSP') --PS ScanedOut
	      GOTO ScanOut_Fail
		END

      -- Check if orders already shipped
   	SELECT @cZone = Zone
   	FROM  dbo.PickHeader WITH (NOLOCK)
   	WHERE PickHeaderKey = @cPickslip

	   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'   	
	   BEGIN
	      IF EXISTS (
	         SELECT 1
      		FROM dbo.PickHeader PickHeader WITH (NOLOCK)
      		JOIN dbo.RefKeyLookup RefKeyLookup WITH (NOLOCK) ON (PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo)
      		JOIN dbo.Orders Orders WITH (NOLOCK) ON (RefKeyLookup.Orderkey = ORDERS.Orderkey)
      		WHERE PickHeader.PickHeaderKey = @cPickslip
      		   AND Orders.Status = '9'
      		   AND PickHeader.Zone IN ('XD', 'LB', 'LP'))
   		BEGIN			
   	      SET @nErrNo = 65705
   	      SET @cErrMsg = rdt.rdtgetmessage( 65705, @cLangCode, 'DSP') --OrderShipped
	         GOTO ScanOut_Fail
		   END
	   END
	   ELSE
		BEGIN			
		   IF EXISTS(
		      SELECT 1 
		      FROM dbo.PickHeader PickHeader WITH (NOLOCK)
		      JOIN dbo.Orders Orders WITH (NOLOCK) ON (PickHeader.Orderkey = ORDERS.Orderkey)
		      WHERE PickHeader.PickHeaderKey = @cPickslip
		         AND PickHeader.Orderkey > ''
		         AND ORDERS.Status = '9'
		         AND PickHeader.Zone NOT IN ('XD', 'LB', 'LP')
		      UNION 
		      SELECT 1
		      FROM dbo.PickHeader PickHeader WITH (NOLOCK)
		      JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON PickHeader.ExternOrderkey = ORDERS.Loadkey
		      WHERE PickHeaderKey = @cPickslip
   		      AND PickHeader.ExternOrderkey > ''
   		      AND pickheader.Orderkey = ''
   		      AND ORDERS.Status = '9'
   		      AND Zone NOT IN ('XD', 'LB', 'LP'))
         BEGIN			
   	      SET @nErrNo = 65706
   	      SET @cErrMsg = rdt.rdtgetmessage( 65706, @cLangCode, 'DSP') --OrderShipped
	         GOTO ScanOut_Fail
		   END
		END

      -- If config turned off and pack not confirmed, prompt error
      IF EXISTS(
         SELECT 1 
         FROM dbo.StorerConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'CheckPickB4Pack'
            AND SValue <> '1')
      BEGIN
         SELECT @cStatus = Status
   	   FROM dbo.PackHeader WITH (NOLOCK)
   	   WHERE pickslipno = @cPickslip

         -- Packing started but not confirmed
         IF ISNULL(@cStatus, '') <> '' AND @cStatus <> '9'
         BEGIN			
   	      SET @nErrNo = 65707
   	      SET @cErrMsg = rdt.rdtgetmessage( 65707, @cLangCode, 'DSP') --PackNotConfirm
	         GOTO ScanOut_Fail
		   END         
      END         

      -- (james02)
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslip, @nValid OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     + 
               '@nInputKey    INT,       '     +
               '@cStorerKey   NVARCHAR( 15), ' + 
               '@cPickslip    NVARCHAR( 10), ' + 
               '@nValid       INT            OUTPUT,  ' + 
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPickslip, @nValid OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nValid = 0
            BEGIN
	            GOTO ScanOut_Fail
            END
         END
      END
      
      -- If config turned on and pack not started , prompt error
      IF EXISTS(
         SELECT 1 
         FROM dbo.StorerConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'PackIsCompulsory'
            AND SValue = '1')
      BEGIN
         SELECT @cStatus = Status
   	   FROM dbo.PackHeader WITH (NOLOCK)
   	   WHERE pickslipno = @cPickslip

         -- Packing not started
         IF ISNULL(@cStatus, '') = '' OR @cStatus <> '9'
         BEGIN			
   	      SET @nErrNo = 65708
   	      SET @cErrMsg = rdt.rdtgetmessage( 65708, @cLangCode, 'DSP') --PackNotDone
	         GOTO ScanOut_Fail
		   END         
      END

      EXECUTE dbo.nspGetRight
         '',
         @cStorerKey,  
         '', 
         'OWITF', 
         @b_success             OUTPUT,
         @cOWITF                OUTPUT,
         @nErrNo                OUTPUT,
         @cErrMsg               OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 65709
         SET @cErrMsg = rdt.rdtgetmessage( 65709, @cLangCode, 'DSP') --'nspGetRight'
         GOTO ScanOut_Fail
      END
      
      EXECUTE dbo.nspGetRight
         '',
         @cStorerKey,  
         '', 
         'PICK-TRF', 
         @b_success             OUTPUT,
         @cPICK_TRF             OUTPUT,
         @nErrNo                OUTPUT,
         @cErrMsg               OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 65710
         SET @cErrMsg = rdt.rdtgetmessage( 65710, @cLangCode, 'DSP') --'nspGetRight'
         GOTO ScanOut_Fail
      END

      -- IF OWITF & PICK-TRF turn on, check for trxlog OWLPLAN rec. Not allow to scan out if LP not yet finalize
      IF @cOWITF = '1' AND @cPICK_TRF = '1'
      BEGIN
         IF NOT EXISTS(
			SELECT 1
		 	FROM  dbo.TRANSMITLOG TL WITH (NOLOCK)
		 	JOIN  dbo.ORDERS O WITH (NOLOCK) ON (TL.Key1 = O.Orderkey)
		 	JOIN  dbo.PICKHEADER P WITH (NOLOCK) ON (O.Loadkey = P.ExternOrderkey)
			WHERE TL.TABLENAME = 'OWLPLAN' 
   			AND   P.ExternOrderkey <> ''
   			AND   P.Pickheaderkey = @cPickslip)
   		BEGIN
   		   IF NOT EXISTS(
				SELECT 1
				FROM  dbo.TRANSMITLOG TL WITH (NOLOCK)
				JOIN  dbo.ORDERS O WITH (NOLOCK) ON (TL.Key1 = O.Orderkey)
				JOIN  dbo.PICKHEADER P WITH (NOLOCK) ON (O.Orderkey = P.Orderkey AND O.Loadkey = P.Wavekey)
				WHERE TL.TABLENAME = 'OWLPLAN' 
   				AND   P.Pickheaderkey = @cPickslip)
   		   BEGIN
               SET @nErrNo = 65711
               SET @cErrMsg = rdt.rdtgetmessage( 65711, @cLangCode, 'DSP') --'LPNotFinalize'
               GOTO ScanOut_Fail   		      
   		   END   
   		END   
      END

      -- SOS132566 (Start)
      SET @cAllowScanOutPKSlipStatus4 = ''
      SET @cAllowScanOutPKSlipStatus4 = rdt.RDTGetConfig( 0, 'AllowScanOutPKSlipStatus4', @cStorerKey)

      IF @cAllowScanOutPKSlipStatus4 = '1'
      BEGIN
         -- Check whether the pickslip with bal qty to be picked
         IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickslip
               AND Status < '4'
               AND QTY > 0)
         BEGIN
            SET @nErrNo = 65713
            SET @cErrMsg = rdt.rdtgetmessage( 65713, @cLangCode, 'DSP') --'w/BalToPick'
            GOTO ScanOut_Fail   
         END
      END
      -- SOS132566 (End)

      -- Scan Out Start
      BEGIN TRAN

      EXEC dbo.isp_ScanOutPickslip
	      @c_PickSlipNo 		= @cPickslip, 
	      @n_err            = @n_err OUTPUT,
	      @c_errmsg         = @c_errmsg OUTPUT          
	      
	   IF @n_err <> 0
      BEGIN
         ROLLBACK TRAN
         
	      SET @nErrNo = 65712
	      SET @cErrMsg = rdt.rdtgetmessage( 65712, @cLangCode, 'DSP') --ScanOutFail         
         GOTO ScanOut_Fail
      END   

      COMMIT TRAN
      -- Scan Out End

      SET @cErrMsg = rdt.rdtgetmessage( 65714, @cLangCode, 'DSP') --'PKScnOutScsful'
      SET @cOutField01 = ''

      SET @nScn = @nScn_ScanOut
      SET @nStep = @nStep_ScanOut
      
      GOTO Quit
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

   ScanOut_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cPickslip = ''
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
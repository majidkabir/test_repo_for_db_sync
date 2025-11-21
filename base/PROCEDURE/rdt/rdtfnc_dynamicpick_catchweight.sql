SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DynamicPick_CatchWeight                      */
/* Copyright      : IDS                                                 */
/* FBR: 85867                                                           */
/* Purpose: Print carton label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 20-Sep-2007  1.0  James      Created                                 */
/* 30-Sep-2016  1.1  Ung        Performance tuning                      */
/* 01-Nov-2018  1.2  TungGH     Performance                             */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DynamicPick_CatchWeight](
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

	@cLabelNo       NVARCHAR( 20),
	@cUCCNo         NVARCHAR( 20),
	@cCongsinee     NVARCHAR( 15),
	@cCartonNo      NVARCHAR( 4),
   @cPickSlipNo    NVARCHAR( 10),
   @nFocusField    INT, 
   @cQTY           NVARCHAR( 5),    
   @cWeight        NVARCHAR( 20),    
   @cCube          NVARCHAR( 20),    
   @nCartonCnt     INT, 
   @nTotalCarton   INT, 
   
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
   @cQTY             = V_QTY,
   @cPickSlipNo      = V_PickSlipNo,

   @cWeight          = V_String1,
   @cCube            = V_String2,
   @cCartonNo        = V_String4,
   
   @nFocusField      = V_Integer1,
   @nCartonCnt       = V_Integer2,
   @nTotalCarton     = V_Integer3,

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
   @nStep_ScanLBL_UCC INT,  @nScn_ScanLBL_UCC INT, 
   @nStep_ScanWGT_CUBE INT,  @nScn_ScanWGT_UCC INT,
   @nStep_Message INT,  @nScn_Message INT

SELECT
   @nStep_ScanLBL_UCC  = 1,  @nScn_ScanLBL_UCC = 1580, 
   @nStep_ScanWGT_CUBE = 2,  @nScn_ScanWGT_UCC = 1581,
   @nStep_Message      = 3,  @nScn_Message     = 1582

IF @nFunc = 920
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 920
   IF @nStep = 1  GOTO Step_ScanLBL_UCC    -- Scn = 1580. Scan Label/UCC
   IF @nStep = 2  GOTO Step_ScanWGT_CUBE   -- Scn = 1581. Scan Weight/Cube
   IF @nStep = 3  GOTO Step_Message        -- Scn = 1582. Msg scn
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 920
********************************************************************************/
Step_Start:
BEGIN
  
   -- Prepare next screen var
   SET @cOutField01 = '' -- Label No
   SET @cOutField02 = '' -- UCC No

   -- Go to Parent screen
   SET @nScn = @nScn_ScanLBL_UCC
   SET @nStep = @nStep_ScanLBL_UCC
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
Scn = 1580. Scan Label/UCC
   Label No    (field01, input)
   UCC No      (field02, input)
********************************************************************************/
Step_ScanLBL_UCC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

       SET @cLabelNo = @cInField01
       SET @cUCCNo = @cInField02

		--if both input also blank
		IF ISNULL(@cLabelNo, '') = '' AND ISNULL(@cUCCNo, '') = ''
		BEGIN			
	      SET @nErrNo = 63576
	      SET @cErrMsg = rdt.rdtgetmessage( 63576, @cLangCode, 'DSP') --LBL/UCC needed
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO Step_ScanLBL_UCC_Fail
		END

		--if both input also scanned in
		IF ISNULL(@cLabelNo, '') <> '' AND ISNULL(@cUCCNo, '') <> ''
		BEGIN			
	      SET @nErrNo = 63577
	      SET @cErrMsg = rdt.rdtgetmessage( 63577, @cLangCode, 'DSP') --Either LBL/UCC
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO Step_ScanLBL_UCC_Fail
		END

		IF @cLabelNo <> ''
		BEGIN				 			       
			IF NOT EXISTS (SELECT 1 FROM dbo.PACKDETAIL (NOLOCK)
				WHERE STORERKEY = @cStorerKey
					AND LABELNO = @cLabelNo)
			BEGIN			
		      SET @nErrNo = 63578
		      SET @cErrMsg = rdt.rdtgetmessage( 63578, @cLangCode, 'DSP') --Bad LABEL NO
		      EXEC rdt.rdtSetFocusField @nMobile, 01
		      GOTO Step_ScanLBL_UCC_Fail
			END
         ELSE   --if packdetail.labelno exists then start getting cartonno, consigneekey, pickslipno
         BEGIN
            --lookup for carton no
            SELECT @cCartonNo = CartonNo 
            FROM dbo.PACKDETAIL WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LabelNo = @cLabelNo 
        
            --lookup pickslipno
            SELECT @cPickSlipNo = PickslipNo 
            FROM dbo.PACKDETAIL WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND CartonNo = @cCartonNo
               AND LabelNo  = @cLabelNo 
         END

         --set field focus on field no. 1                  
         SET @nFocusField = 1
      END


		IF @cUCCNo <> ''
		BEGIN				 			       
			IF NOT EXISTS (SELECT 1 FROM dbo.PACKDETAIL (NOLOCK)
				WHERE STORERKEY = @cStorerKey
					AND REFNO = @cUCCNo)
			BEGIN			
		      SET @nErrNo = 63579
		      SET @cErrMsg = rdt.rdtgetmessage( 63579, @cLangCode, 'DSP') --Bad UCC NO
		      EXEC rdt.rdtSetFocusField @nMobile, 02
		      GOTO Step_ScanLBL_UCC_Fail
			END
         ELSE
         BEGIN   --if packdetail.refno exists then start getting cartonno, consigneekey, pickslipno
            --lookup for carton no
            SELECT @cCartonNo = CartonNo 
            FROM dbo.PACKDETAIL WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND RefNo = @cUCCNo 

            --lookup pickslipno
            SELECT @cPickSlipNo = PickslipNo 
            FROM dbo.PACKDETAIL WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND CartonNo = @cCartonNo
               AND RefNo = @cUCCNo 
         END            

         --set field focus on field no. 2
         SET @nFocusField = 2
      END

      --if catch weight record exists, show its qty, weight, cube
      IF EXISTS (SELECT 1 FROM dbo.PACKINFO WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo  = @cCartonNo) 
      BEGIN   
         SELECT @cQTY    = Qty, 
                @cWeight = Weight, 
                @cCube   = Cube 
         FROM dbo.PackInfo WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo  = @cCartonNo 

         SET @cOutField04 = @cWeight
         SET @cOutField05 = @cCube
      END   
      ELSE   --if catch weight record not exists, sum(packdetail.qty)
      BEGIN
         SELECT @cQTY = SUM(Qty) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickslipNo = @cPickSlipNo                
            AND CartonNo = @cCartonNo

         SET @cOutField04 = ''
         SET @cOutField05 = '' 
      END

      --get the count of carton scanned
      SELECT @nCartonCnt = COUNT(1)  
      FROM dbo.PackInfo WITH (NOLOCK) 
      WHERE PickslipNo = @cPickSlipNo                

      --get the total carton
      SELECT @nTotalCarton = COUNT(DISTINCT CartonNo) 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND PickslipNo = @cPickSlipNo                

      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cCartonNo 
      SET @cOutField03 = @cQTY 
      SET @cOutField06 = @nCartonCnt
      SET @cOutField07 = @nTotalCarton


      SET @nScn = @nScn_ScanWGT_UCC
      SET @nStep = @nStep_ScanWGT_CUBE

      GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Label No
      SET @cOutField02 = '' -- UCC No
      SET @cOutField03 = ''
      SET @cOutField04 = '' 
   END
   
   GOTO Quit

   Step_ScanLBL_UCC_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = '' 
   END
 
END
GOTO Quit

/********************************************************************************
Scn = 1581. Scan Weight & Cube
   Pickslip No (field01, display)
   Carton No   (field02, display)
   Qty         (field03, display)
   Weight      (field04, input)
   Cube        (field05, input)
   Scan/Total  (field06 & field07, display)
********************************************************************************/
Step_ScanWGT_CUBE:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

       SET @cWeight = @cInField04
       SET @cCube = @cInField05

		--if both input also blank or zero
		IF (ISNULL(@cWeight, '') = '' AND ISNULL(@cCube, '') = '') OR (@cWeight = '0' AND @cCube = '0')
		BEGIN			
	      SET @nErrNo = 63580
	      SET @cErrMsg = rdt.rdtgetmessage( 63580, @cLangCode, 'DSP') --Need WGT/CUBE
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO Step_ScanWGT_CUBE_Fail
		END

      --if blank then taken as 0 (zero)
      IF @cWeight = '' SET @cWeight = '0'
      IF @cCube = '' SET @cCube = '0'

      --check if weight scanned is valid or not (not alphabet & not -ve)
      IF ISNUMERIC(@cWeight) = 0 
         OR @cWeight = '-0' 
         OR @cWeight = '+' 
         OR @cWeight = '.' 
         OR @cWeight = '-' 
         OR CAST(@cWeight AS FLOAT) < 0
		BEGIN			
	      SET @nErrNo = 63581
	      SET @cErrMsg = rdt.rdtgetmessage( 63581, @cLangCode, 'DSP') --Invalid weight
      	SET @cOutField04 = ''
	      EXEC rdt.rdtSetFocusField @nMobile, 04
--	      GOTO Step_ScanWGT_CUBE_Fail
         GOTO QUIT
		END

      --check if cube scanned is valid or not (not alphabet & not -ve)
      IF ISNUMERIC(@cCube) = 0 
         OR @cCube = '-0'
         OR @cCube = '+'
         OR @cCube = '.'
         OR @cCube = '-'
         OR CAST(@cCube AS FLOAT) < 0 
		BEGIN			
	      SET @nErrNo = 63582
	      SET @cErrMsg = rdt.rdtgetmessage( 63582, @cLangCode, 'DSP') --Invalid cube
      	SET @cOutField05 = ''
	      EXEC rdt.rdtSetFocusField @nMobile, 05
--	      GOTO Step_ScanWGT_CUBE_Fail
         GOTO QUIT
		END

      IF NOT EXISTS (SELECT 1 FROM dbo.PACKINFO WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo  = @cCartonNo) 
      BEGIN
         BEGIN TRAN
   
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType)            
         VALUES
         (@cPickSlipNo, @cCartonNo, CAST(@cQty AS INT), CAST(@cWeight AS FLOAT), CAST(@cCube AS FLOAT), '')

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 63583
            SET @cErrMsg = rdt.rdtgetmessage( 63583, @cLangCode, 'DSP') --'INSTPackInFail'
            GOTO Quit
         END

         COMMIT TRAN
      END   
      ELSE   
      BEGIN
         BEGIN TRAN

         UPDATE dbo.PackInfo SET
            Weight = CAST(@cWeight AS FLOAT), 
            Cube = CAST(@cCube AS FLOAT) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo  = @cCartonNo         

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 63584
            SET @cErrMsg = rdt.rdtgetmessage( 63584, @cLangCode, 'DSP') --'UPDPackInFail'
            GOTO Quit
         END

         COMMIT TRAN  
      END

      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message

      GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  

      SET @cOutField01 = '' -- Label No
      SET @cOutField02 = '' -- UCC No

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      --set focus on previous scanned field
      EXEC rdt.rdtSetFocusField @nMobile, @nFocusField
   END
   
   GOTO Quit

   Step_ScanWGT_CUBE_Fail:
   BEGIN
      SET @cOutField04 = ''
      SET @cOutField05 = '' 
   END
 
END
GOTO Quit

/********************************************************************************
Scn = 1582. Message Screen
********************************************************************************/
Step_Message:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOutField01 = '' -- Label No
      SET @cOutField02 = '' -- UCC No

      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      --set focus on previous scanned field
      EXEC rdt.rdtSetFocusField @nMobile, @nFocusField

      GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN  

      SET @cOutField01 = '' -- Label No
      SET @cOutField02 = '' -- UCC No

      -- Go to prev screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2

      --set focus on previous scanned field
      EXEC rdt.rdtSetFocusField @nMobile, @nFocusField

   END
   
   GOTO Quit

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
      
      V_QTY        = @cQTY,
      V_PickSlipNo = @cPickSlipNo,

      V_String1    = @cWeight, 
      V_String2    = @cCube,  
      V_String4    = @cCartonNo, 
      
      V_Integer1   = @nFocusField,
      V_Integer2   = @nCartonCnt, 
      V_Integer3   = @nTotalCarton, 

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
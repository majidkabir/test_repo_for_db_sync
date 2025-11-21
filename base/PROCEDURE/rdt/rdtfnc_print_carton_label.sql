SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: RDT Print Carton Label  166488                                    */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2010-01-20 1.0  ChewKP     Created                                         */ 
/* 2010-08-19 1.1  ChewKP     SOS#185146 Carter Bartender Label Printing      */
/*                            change request (ChewKP01)                       */
/* 2010-12-09 1.2  ChewKP     SOS#197571 FedEx Ground label and FedEx Express */
/*                            label for Carter checking (ChewKP02)            */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Print_Carton_Label] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cPrinter   NVARCHAR( 20), 
   @cUserName  NVARCHAR( 18),
   
   @nError     INT,
   @b_success  INT,
   @n_err      INT,     
   @c_errmsg   NVARCHAR( 250), 
	@cPUOM	 NVARCHAR( 1),
	@cLabelNo NVARCHAR(20),
	@nCartonNo	INT,

	@cGS1TemplatePath		 NVARCHAR(120),
	@cGS1TemplatePath_Final NVARCHAR(120),
	@cOrderKey				 NVARCHAR( 10),
	@cM_Country				 NVARCHAR( 30),
	@dTempDateTime				DATETIME,
	@cFileName				 NVARCHAR(215),
	@cTemplateID			 NVARCHAR( 20),
	@cSuccessMsg			 NVARCHAR( 50),
	@cYYYY					 NVARCHAR( 4),
   @cMM						 NVARCHAR( 2),
   @cDD						 NVARCHAR( 2),
   @cHH						 NVARCHAR( 2),
   @cMI						 NVARCHAR( 2),
   @cSS						 NVARCHAR( 2),
	@cMS						 NVARCHAR( 3),
	@cDateTime				 NVARCHAR( 17),
	@cUPC                   NVARCHAR( 30),    --(ChewKP01)
   @cMCountry              NVARCHAR( 30),    --(ChewKP02)

      
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
   
-- Load RDT.RDTMobRec
SELECT 
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer, 
   @cUserName  = UserName,
   
   @cPUOM       = V_UOM,
   @cOrderKey   = V_OrderKey,
   
	@cLabelNo    = V_String1,
   

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT

SET @n_debug = 0

IF @n_debug = 1
	BEGIN
		DECLARE  @d_starttime    datetime,
				   @d_endtime      datetime,
				   @d_step1        datetime,
				   @d_step2        datetime,
				   @d_step3        datetime,
				   @d_step4        datetime,
				   @d_step5        datetime,
				   @c_col1         NVARCHAR(20),
				   @c_col2         NVARCHAR(20),
				   @c_col3         NVARCHAR(20),
				   @c_col4         NVARCHAR(20),
				   @c_col5         NVARCHAR(20),
				   @c_TraceName    NVARCHAR(80)

		SET @c_col1 = ''
		--SET @c_col1 = @cOrderKey
		--SET @c_col2 = @cSKU
		--SET @c_col3 = @nQTY
		SET @c_col4 = @cPrinter

		SET @d_starttime = getdate()

		SET @c_TraceName = 'rdt_Print_Carton_Label'
	END


IF @nFunc = 1774  -- Print Carton Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Print Carton Label
   IF @nStep = 1 GOTO Step_1   -- Scn = 2290. LabelNo
	IF @nStep = 2 GOTO Step_2   -- Scn = 2291. Display
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END


--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1752. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

	--SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   --SET @nCasePackDefaultQty =  CAST(rdt.RDTGetConfig( @nFunc, 'CasePackDefaultQty', @cStorerKey) AS INT)

   -- Initiate var

   -- Init screen
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
	SET @cOutField03 = '' 

   -- Set the entry point
	SET @nScn = 2290
	SET @nStep = 1
	
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2290. 
   LabelNo (field01, input)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	 
	    SET @nCartonNo = 0
	    SET @cLabelNo = ''
		
		
		SET @cLabelNo = ISNULL(RTRIM(@cInField01),'')
		

		SET @cSuccessMsg = 'Label Printed'

		
		IF ISNULL(@cPrinter,'') = ''
	    BEGIN
	      SET @nErrNo = 69066
	      SET @cErrMSG = rdt.rdtgetmessage( 69066, @cLangCode,'DSP') --Printer ID req
			SET @cSuccessMsg = ''
	      GOTO QUIT
       END


	   IF ISNULL(@cLabelNo,'') = ''
	    BEGIN
	      SET @nErrNo = 69067
	      SET @cErrMSG = rdt.rdtgetmessage( 69067, @cLangCode,'DSP') --LabelNo req
			SET @cSuccessMsg = ''
	      GOTO QUIT
       END
  

		-- Validate LabelNo
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail WITH (NOLOCK)
	      WHERE LabelNo =  @cLabelNo AND Storerkey = @cStorerkey)
      BEGIN
	      SET @nErrNo = 69068
	      SET @cErrMSG = rdt.rdtgetmessage( 69068, @cLangCode,'DSP') --Invalid Label
			SET @cSuccessMsg = ''
			GOTO QUIT
	   END 
	   
	   -- (ChewKP02) Start
	   SET @cMCountry = ''
	   
      SELECT @cMCountry = O.M_Country FROM dbo.PackDetail PD WITH (NOLOCK) 
      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.PickHeaderkey = PD.PickSlipNo 
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PH.Orderkey 
      WHERE O.Storerkey = @cStorerkey
      AND PD.LabelNo = @cLabelNo
      
      IF ISNULL(RTRIM(@cMCountry),'') = 'USA'
      BEGIN

   	   -- Validate UPC -- Start (ChewKP01)
   	   SET @cUPC = ''
   	   SELECT @cUPC = UPC FROM dbo.PackDetail WITH (NOLOCK)
   	   WHERE LabelNo = @cLabelNo AND Storerkey = @cStorerkey
   	   
         
   	   IF LEN(ISNULL(RTRIM(@cUPC),'')) <> 22
   	   BEGIN
   	      SET @nErrNo = 69070
   	      SET @cErrMSG = rdt.rdtgetmessage( 69070, @cLangCode,'DSP') --Inv UPC Length
   			SET @cSuccessMsg = ''
   	      GOTO QUIT
         END
      
   
         IF SUBSTRING (@cUPC, 1,2) <> '96'
         BEGIN
   	      SET @nErrNo = 69071
   	      SET @cErrMSG = rdt.rdtgetmessage( 69071, @cLangCode,'DSP') --Invalid UPC 
   			SET @cSuccessMsg = ''
   	      GOTO QUIT
         END
         -- Validate UPC -- End (ChewKP01)
      
	   END -- (ChewKP02) End
	   
	   
		SELECT @cGS1TemplatePath = UserDefine20 FROM dbo.Facility (NOLOCK)
				WHERE Facility = @cFacility
		IF ISNULL(@cGS1TemplatePath,'') = ''
	    BEGIN
	      SET @nErrNo = 69069
	      SET @cErrMSG = rdt.rdtgetmessage( 69069, @cLangCode,'DSP') --FilePath req
			SET @cSuccessMsg = ''
	      GOTO QUIT
       END
		

		 SET @nCartonNo = 0
	    

		 SET @cSuccessMsg = 'Label Printed'
			
       DECLARE CUR_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 

		 SELECT DISTINCT O.Orderkey , O.M_Country, PD.CartonNo FROM dbo.PackDetail PD WITH (NOLOCK)
		 INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo ) 
		 INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PH.ORDERKEY ) 
		 WHERE PD.LabelNo = @cLabelNo
		 AND PD.Storerkey = @cStorerkey
			

	    OPEN CUR_ORDER
	    FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cM_Country, @nCartonNo
	    WHILE @@FETCH_STATUS <> -1
	    BEGIN
			 
				

				IF ISNULL(@cM_Country,'') = 'USA'
				BEGIN
					SET @dTempDateTime = GetDate()

					SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
					SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
					SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
					SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
					SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
					SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)
					SET @cMS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ms, @dTempDateTime)), ''), 3)


					SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS

					SET @cFileName = ISNULL(RTRIM(@cPrinter),'') + '_' + @cDateTime + '_' +  ISNULL(RTRIM(@cLabelNo),'') + '.XML'

					SET @cTemplateID =  'FedExGround.btw'
				
					
				   EXEC RDT.rdt_CartonLabel_GenXML
                  @cLabelNo
                , @cOrderKey   
                , @cTemplateID 
					 , @cPrinter  
                , @cFileName    
                , @cStorerkey    
                , @cGS1TemplatePath   
					 , @nErrNo        OUTPUT
					 , @cErrMsg       OUTPUT 
			
					

             
				END
				ELSE -- ISNULL(@cM_Country,'') = 'USA'
				BEGIN
					SET @dTempDateTime = GetDate()

					SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
					SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
					SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
					SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
					SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
					SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)
					SET @cMS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ms, @dTempDateTime)), ''), 3)


					SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS

					SET @cFileName = ISNULL(RTRIM(@cPrinter),'') + '_' + @cDateTime + '_' +  ISNULL(RTRIM(@cLabelNo),'') + '.XML'

               SET @cTemplateID =  'FedExExpress.btw'
               
                EXEC RDT.rdt_CartonLabel_GenXML
                  @cLabelNo
                , @cOrderKey   
                , @cTemplateID 
					 , @cPrinter  
                , @cFileName    
                , @cStorerkey    
                , @cGS1TemplatePath   
					 , @nErrNo        OUTPUT
					 , @cErrMsg       OUTPUT 
               
					
					
					

					SET @dTempDateTime = GetDate()

					SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
					SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
					SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
					SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
					SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
					SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)
					SET @cMS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ms, @dTempDateTime)), ''), 3)


					SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS

					SET @cFileName = ISNULL(RTRIM(@cPrinter),'') + '_' + @cDateTime + '_' +  ISNULL(RTRIM(@cLabelNo),'') + '.XML'
               SET @cTemplateID =  'GenericCarton.btw'
               
               
                 EXEC RDT.rdt_CartonLabel_GenXML
                  @cLabelNo
                , @cOrderKey   
                , @cTemplateID 
					 , @cPrinter  
                , @cFileName    
                , @cStorerkey    
                , @cGS1TemplatePath   
					 , @nErrNo        OUTPUT
					 , @cErrMsg       OUTPUT 
               
					

				END	
          
		            

			FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cM_Country, @nCartonNo
      
		 END
		CLOSE CUR_ORDER
		DEALLOCATE CUR_ORDER
	   -- Loop of SKU for Packing and GS1 Label generation (END) --
		

		
			
	END  -- Inputkey = 1
	
--				IF @nSetTemplate <> 1
--				BEGIN
			-- Prepare next screen var


	SET @cOutField01 = @cLabelNo
	SET @cOutField02 = @nCartonNo
	SET @cOutField03 = @cSuccessMsg
	SET @nScn = @nScn + 1
	SET @nStep = @nStep + 1
	
--				END
END 

IF @nInputKey = 0 
BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
END

GOTO QUIT

/********************************************************************************
Step 2. Scn = 2291. 
   LabelNo (field01, output)
	CartonNo(field02, output)
	Msg	  (field03, output)	
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	
--				IF @nSetTemplate <> 1
--				BEGIN
			-- Prepare next screen var
	
	SET @cOutField01 = ''
	SET @cOutField02 = ''
	SET @cOutField03 = ''
	SET @nScn = @nScn - 1
	SET @nStep = @nStep - 1
   
--				END
  END -- input = 1
  GOTO QUIT	
END
--IF @nInputKey = 0 
--BEGIN
--      --go to main menu
--      SET @nFunc = @nMenu
--      SET @nScn  = @nMenu
--      SET @nStep = 0
--      SET @cOutField01 = ''
--END
--IF @nInputKey = 0 --ESC
--BEGIN
--
--	SET @cOutField01 = ''
--	SET @cOutField02 = ''
--	SET @cOutField03 = ''
--	SET @nScn = @nScn - 1
--	SET @nStep = @nStep - 1
--   
--
--END -- input = 0
--
--GOTO QUIT	   



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
      Printer   = @cPrinter, -- (ChewKP03)
      UserName  = @cUserName,
		InputKey  =	@nInputKey,
		

      V_UOM = @cPUOM,
      --V_QTY = @nQTY,
      --V_SKU = @cSKU,

      --V_SKUDescr   = @cDescr,
      --V_PickSlipNo = @cPickSlipNo,
      --V_OrderKey   = @cOrderKey,
      --V_LoadKey    = @cLoadKey,
      
		V_String1 = @cLabelNo,
      --V_String6  = @cUPC_SKU,
      --V_String7  = @cPickSlipType,
      --V_String8  = @cMBOLKey,
      --V_String9  = @cBuyerPO,         
      --V_String10 = @cTemplateID,
      --V_String11 = @cFilePath1,
      --V_String12 = @cFilePath2, 
      
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
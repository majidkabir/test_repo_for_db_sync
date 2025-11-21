SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: RDT Print Pallet Label  SOS#200915                                */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2011-01-13 1.0  ChewKP     Created                                         */ 
/* 2016-09-30 1.1  Ung        Performance tuning                              */     
/* 2018-11-08 1.2  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Print_Pallet_Label] (
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

	@cGS1FilePath		 NVARCHAR(120),
	@cGS1FilePath_Final NVARCHAR(120),
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
	@cUPC                   NVARCHAR( 30),    
   @cMCountry              NVARCHAR( 30), 
   @cDropID                NVARCHAR( 18), 
   @cLoadkey               NVARCHAR( 10),  
   @cGS1TemplatePath_Gen   NVARCHAR(120),
   

      
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
	@cDropID     = V_String2,
   

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


IF @nFunc = 912  -- Print Carton Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Print Pallet Label
   IF @nStep = 1 GOTO Step_1   -- Scn = 2640. LabelNo
	IF @nStep = 2 GOTO Step_2   -- Scn = 2641. Display
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END


--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 912. Menu
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
	   -- EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep


   -- Init screen
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
	SET @cOutField03 = '' 
	
	SET @cLabelNo = ''
	SET @cDropID  = ''

   -- Set the entry point
	SET @nScn = 2640
	SET @nStep = 1
	
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2640. 
   Printer (field01, input)
   DropID  (field02, input)
   LabelNo (field03, input)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cPrinter = ISNULL(RTRIM(@cInField01),'')
		SET @cDropID  = ISNULL(RTRIM(@cInField02),'')
		SET @cLabelNo = ISNULL(RTRIM(@cInField03),'')

		
		IF ISNULL(@cPrinter,'') = ''
	    BEGIN
	      SET @nErrNo = 72041
	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Printer ID req
			
	      GOTO STEP_1_FAIL
       END

	   IF ISNULL(@cLabelNo,'') = '' AND  ISNULL(@cDropID,'') = ''
	    BEGIN
	      SET @nErrNo = 72042
	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DropID/LBL Req
			GOTO STEP_1_FAIL
       END

      -- Retrieve DropID from LabelNo 
      SET @cLoadkey = ''
      
      IF ISNULL(@cDropID ,'') = ''
      BEGIN
         
         SELECT @cDropID = DD.DropID FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.DropID DropID WITH (NOLOCK) ON DropID.DropID = DD.DropID
         WHERE DD.ChildID = @cLabelNo
         
         IF ISNULL(@cDropID,'') = ''
         BEGIN
               SET @nErrNo = 72043
      	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Label
      			SET @cSuccessMsg = ''
      	      GOTO QUIT
         END
      	   
   	   SELECT @cLoadkey = D.Loadkey, @cDropID = D.DropID FROM dbo.DropID D WITH (NOLOCK)
   	   INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = D.DropID
   	   WHERE DD.ChildID = @cLabelNo
      END  
      ELSE
      BEGIN
         
         SELECT @cLoadkey = D.Loadkey FROM dbo.DropID D WITH (NOLOCK)
   	   INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = D.DropID
   	   WHERE D.DropID = @cDropID
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID DropID WITH (NOLOCK) 
                     INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = DropID.DropLoc
                     WHERE DropID.DropID = @cDropID
                     AND   DropID.DropIDType = 'C'
                     AND   Loc.LocationCategory IN ('STAGING','PROC' ))
      BEGIN
               SET @nErrNo = 72044
      	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PLT NOT FOR STAGE
      			SET @cSuccessMsg = ''
      	      GOTO QUIT
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                 WHERE DropID = @cDropID
                 AND DropIDType = 'P' )
      BEGIN
               SET @nErrNo = 72046
      	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PLT NOT FOR STAGE
      			SET @cSuccessMsg = ''
      	      GOTO QUIT
      END

         
      
		SELECT @cGS1FilePath = UserDefine20 FROM dbo.Facility (NOLOCK)
				WHERE Facility = @cFacility
				
		 IF ISNULL(@cGS1FilePath,'') = ''
	    BEGIN
	      SET @nErrNo = 72045
	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --FilePath req
			GOTO STEP_1_FAIL
       END
		
		
		SET @cGS1TemplatePath_Gen = ''
		
		SELECT @cGS1TemplatePath_Gen = NSQLDescrip
		FROM RDT.NSQLCONFIG WITH (NOLOCK)
		WHERE ConfigKey = 'GS1TemplatePath'
		
		
      SET @dTempDateTime = GetDate()

		SET @cYYYY = RIGHT( '0' + ISNULL(RTRIM( DATEPART( yyyy, @dTempDateTime)), ''), 4)
		SET @cMM = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mm, @dTempDateTime)), ''), 2)
		SET @cDD = RIGHT( '0' + ISNULL(RTRIM( DATEPART( dd, @dTempDateTime)), ''), 2)
		SET @cHH = RIGHT( '0' + ISNULL(RTRIM( DATEPART( hh, @dTempDateTime)), ''), 2)
		SET @cMI = RIGHT( '0' + ISNULL(RTRIM( DATEPART( mi, @dTempDateTime)), ''), 2)
		SET @cSS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ss, @dTempDateTime)), ''), 2)
		SET @cMS = RIGHT( '0' + ISNULL(RTRIM( DATEPART( ms, @dTempDateTime)), ''), 3)


		SET @cDateTime = @cYYYY + @cMM + @cDD + @cHH + @cMI + @cSS + @cMS

		SET @cFileName = ISNULL(RTRIM(@cPrinter),'') + '_' + @cDateTime + '_' +  ISNULL(RTRIM(@cDropID),'') + '.XML'

		SET @cTemplateID =  'DROPID.btw' 
	   
	   
--	   SET @cOrderkey = ''
--	   SELECT @cOrderkey = PH.Orderkey , 
--	          @cStorerkey = PH.Storerkey 
--	   FROM dbo.PackHeader PH WITH (NOLOCK)
--	   INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON PD.PickslipNo = PH.PickSlipNo
--	   WHERE PD.LabelNo = @cLabelNo
--	   AND   PH.Loadkey = @cLoadkey
	   
	   SELECT DISTINCT @cStorerkey = Storerkey 
	   FROM dbo.DropID DropID WITH (NOLOCK)
      INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
      WHERE DropID.DropID = @cDropID
	   

	   
	   EXEC RDT.rdt_PalletLabel_GenXML
         @cDropID
       , '' --@cOrderKey   
       , @cTemplateID 
		 , @cPrinter  
       , @cFileName    
       , @cStorerkey    
       , @cGS1FilePath   
       , @cGS1TemplatePath_Gen
		 , @nErrNo        OUTPUT
		 , @cErrMsg       OUTPUT 
		   
	    IF @nErrNo <> 0 
	    BEGIN
	      
	      SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --FilePath req
			GOTO STEP_1_FAIL
	    END
	    
	    -- EventLog - Sign In Function
       EXEC RDT.rdt_STD_EventLog
        @cActionType = '20', -- Print Label
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cLoadkey    = @cLoadkey,
        --@cRefNo1     = @cLoadkey,
        @cDropID     = @cDropID,
        --@cRefNo2     = @cDropID,
        @cLabelNo    = @cLabelNo,
        --@cRefNo3     = @cLabelNo,
        @nStep       = @nStep
		
		 -- GOTO Next Screen
		 SET @nScn = @nScn + 1
	    SET @nStep = @nStep + 1
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
      -- EventLog - Sign In Function
       EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
        
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
	GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = @cPrinter
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
   
--				END
END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 2641. 
   Message (output)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 --ENTER / ESC
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
	   EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      Printer   = @cPrinter, -- (ChewKP03)
      -- UserName  = @cUserName,
		InputKey  =	@nInputKey,
		

      V_UOM = @cPUOM,
      --V_QTY = @nQTY,
      --V_SKU = @cSKU,

      --V_SKUDescr   = @cDescr,
      --V_PickSlipNo = @cPickSlipNo,
      --V_OrderKey   = @cOrderKey,
      --V_LoadKey    = @cLoadKey,
      
		V_String1 = @cLabelNo,
		V_String2 = @cDropID,
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
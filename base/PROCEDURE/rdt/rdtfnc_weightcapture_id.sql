SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/*	Store	procedure: rdtfnc_WeightCapture_ID										*/
/*	Copyright		: IDS																	*/
/*	FBR: 85867																				*/
/*	Purpose:	Print	carton label														*/
/*																								*/
/*	Modifications log:																	*/
/*																								*/
/*	Date			 Rev	Author	  Purposes											*/
/*	23-Oct-2019	 1.0	Chermaine  WMS-10876	Created								*/	
/*	12-Dec-2019	 1.1	Chermaine  WMS-10876	Add EditDate in					*/	
/*										  update	RDTMOBREC(cc01)						*/
/************************************************************************/

CREATE PROC	[RDT].[rdtfnc_WeightCapture_ID](
   @nMobile		int,
   @nErrNo		int  OUTPUT,
   @cErrMsg		NVARCHAR(1024)	OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT	ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS	OFF
SET CONCAT_NULL_YIELDS_NULL OFF	

--	RDT.RDTMobRec variables
DECLARE
   @nFunc			 INT,
   @nScn				 INT,
   @nStep			 INT,
   @cLangCode		 NVARCHAR( 3),
   @nInputKey		 INT,
   @nMenu			 INT,

   @cStorerKey		 NVARCHAR( 15),
   @cUserName		 NVARCHAR( 18),
   @cFacility		 NVARCHAR( 5),
   @cPrinter		 NVARCHAR( 10),

   @cID				 NVARCHAR( 20),
   @nFocusField	 INT,	
   @cQTY				 NVARCHAR( 5),		
   @cWeight			 NVARCHAR( 20),	 

   @cInField01	NVARCHAR( 60),	  @cOutField01	NVARCHAR( 60),
   @cInField02	NVARCHAR( 60),	  @cOutField02	NVARCHAR( 60),
   @cInField03	NVARCHAR( 60),	  @cOutField03	NVARCHAR( 60),
   @cInField04	NVARCHAR( 60),	  @cOutField04	NVARCHAR( 60),
   @cInField05	NVARCHAR( 60),	  @cOutField05	NVARCHAR( 60),
   @cInField06	NVARCHAR( 60),	  @cOutField06	NVARCHAR( 60),
   @cInField07	NVARCHAR( 60),	  @cOutField07	NVARCHAR( 60),
   @cInField08	NVARCHAR( 60),	  @cOutField08	NVARCHAR( 60),
   @cInField09	NVARCHAR( 60),	  @cOutField09	NVARCHAR( 60),
   @cInField10	NVARCHAR( 60),	  @cOutField10	NVARCHAR( 60),
   @cInField11	NVARCHAR( 60),	  @cOutField11	NVARCHAR( 60),
   @cInField12	NVARCHAR( 60),	  @cOutField12	NVARCHAR( 60),
   @cInField13	NVARCHAR( 60),	  @cOutField13	NVARCHAR( 60),
   @cInField14	NVARCHAR( 60),	  @cOutField14	NVARCHAR( 60),
   @cInField15	NVARCHAR( 60),	  @cOutField15	NVARCHAR( 60)

--	Getting Mobile	information
SELECT
   @nFunc				= Func,
   @nScn					= Scn,
   @nStep				= Step,
   @nInputKey			= InputKey,
   @nMenu				= Menu,
   @cLangCode			= Lang_code,

   @cStorerKey			= StorerKey,
   @cFacility			= Facility,
   @cUserName			= UserName,
   @cPrinter			= Printer, 
   @cQTY					= V_QTY,
   @cID					= V_ID,

   @cWeight				= V_String1,
   --@cCube				  = V_String2,
   @nFocusField		= CASE WHEN	rdt.rdtIsValidQTY( LEFT( V_String3,	5), 0) =	1 THEN LEFT( V_String3,	5)	ELSE 0 END,

   @cInField01	= I_Field01,	@cOutField01 =	O_Field01,
   @cInField02	= I_Field02,	@cOutField02 =	O_Field02,
   @cInField03	= I_Field03,	@cOutField03 =	O_Field03,
   @cInField04	= I_Field04,	@cOutField04 =	O_Field04,
   @cInField05	= I_Field05,	@cOutField05 =	O_Field05,
   @cInField06	= I_Field06,	@cOutField06 =	O_Field06,
   @cInField07	= I_Field07,	@cOutField07 =	O_Field07,
   @cInField08	= I_Field08,	@cOutField08 =	O_Field08,
   @cInField09	= I_Field09,	@cOutField09 =	O_Field09,
   @cInField10	= I_Field10,	@cOutField10 =	O_Field10,
   @cInField11	= I_Field11,	@cOutField11 =	O_Field11,
   @cInField12	= I_Field12,	@cOutField12 =	O_Field12,
   @cInField13	= I_Field13,	@cOutField13 =	O_Field13,
   @cInField14	= I_Field14,	@cOutField14 =	O_Field14,
   @cInField15	= I_Field15,	@cOutField15 =	O_Field15

FROM rdt.rdtMobRec (NOLOCK)
WHERE	Mobile =	@nMobile

IF	@nFunc =	1839
BEGIN
	--	Redirect	to	respective screen
   IF	@nStep =	0	GOTO Step_0		--	Menu.	Func = 1839
   IF	@nStep =	1	GOTO Step_1		--	Scn =	5630.	Scan ID
   IF	@nStep =	2	GOTO Step_2		--	Scn =	5631.	Scan Weight
END

RETURN -- Do nothing	if	incorrect step

/********************************************************************************
Step_0. Func =	1839
********************************************************************************/
Step_0:
BEGIN
   --	Prepare next screen var
   SET @cOutField01 = '' -- ID

   --	Set the entry point 
   SET @nScn =	5630
   SET @nStep = 1

   --	EventLog	 
   EXEC RDT.rdt_STD_EventLog	
	   @cActionType =	'1', -- Sign-in  
	   @cUserID		 =	@cUserName,	 
	   @nMobileNo	 =	@nMobile,  
	   @nFunctionID =	@nFunc,
	   @cFacility	 =	@cFacility,	
	   @cStorerKey	 =	@cStorerKey

END
GOTO Quit
/********************************************************************************
Scn =	5630.	Scan ID
	ID		(field01, input)
********************************************************************************/
Step_1:
BEGIN
	IF	@nInputKey = 1	--	ENTER
	BEGIN

      SET @cID =	@cInField01

      --if input is blank
      IF	ISNULL(@cID, '') = ''
      BEGIN			
	      SET @nErrNo	= 145551
	      SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID needed
	      SET @cOutField01 = ''
	      GOTO Quit 
      END

      IF	@cID <> ''
      BEGIN									 
         --	Validate	ID	and get Qty	
         SELECT TOP 1 1	 
         FROM dbo.LOTxLOCxID WITH (NOLOCK)  
         WHERE	StorerKey =	@cStorerKey	 
         AND ID =	@cID	
  
	      IF	@@ROWCOUNT = 0	 
	      BEGIN	 
		      SET @nErrNo	= 145552
		      SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid	ID	 
		      SET @cOutField01 = ''	
		      GOTO Quit  
	      END  
	      ELSE
	      BEGIN
		      SELECT @cQTY=QTY	
		      FROM dbo.LOTxLOCxID WITH (NOLOCK)  
		      WHERE	StorerKey =	@cStorerKey	 
		      AND ID =	@cID 
	      END
      END      
				  
		SET @cOutField01 = @cID
		SET @cOutField02 = @cQTY 
		SET @cOutField03 = '' 

		SET @nScn =	@nScn	+ 1
		SET @nStep = @nStep + 1

		GOTO Quit
	END
	
   IF	@nInputKey = 0	--	ESC
   BEGIN	 
	   --	EventLog	 
   EXEC RDT.rdt_STD_EventLog	
	   @cActionType =	'9', -- logOut	 
	   @cUserID		 =	@cUserName,	 
	   @nMobileNo	 =	@nMobile,  
	   @nFunctionID =	@nFunc,
	   @cFacility	 =	@cFacility,	
	   @cStorerKey	 =	@cStorerKey
		
   --	Back to menu
   SET @nFunc = @nMenu
   SET @nScn  = @nMenu
   SET @nStep = 0
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = '' -- QTY
   END
	
	GOTO Quit

END
GOTO Quit

/********************************************************************************
Scn =	5631.	Scan Weight
	ID			(field01, display)
	QTY		(field02, display)
	Weight	(field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF	@nInputKey = 1	--	ENTER
   BEGIN

	   SET @cWeight = @cInField03

      --if both input also	blank	or	zero
      IF	(ISNULL(@cWeight,	'')) = '' OR (@cWeight = '0')
      BEGIN			
         SET @nErrNo	= 145553
         SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need	Weight
         SET @cOutField04 = ''
         GOTO QUIT
      END

	   --check if weight	scanned is valid or not	(not alphabet & not -ve)
      IF	ISNUMERIC(@cWeight) = 0	
         OR	@cWeight	= '-0' 
         OR	@cWeight	= '+'	
         OR	@cWeight	= '.'	
         OR	@cWeight	= '-'	
         OR	CAST(@cWeight AS FLOAT)	< 0
      BEGIN			
         SET @nErrNo	= 145554
         SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid	weight
         SET @cOutField04 = ''
         GOTO QUIT
      END
		
      IF	rdt.rdtIsValidFormat( @nFunc,	@cStorerKey, 'Wgt', @cWeight)	= 0
      BEGIN
         SET @nErrNo	= 145555
         SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid	Format
         SET @cOutField04 = ''
         GOTO QUIT
      END
	 
      UPDATE dbo.ID SET
         InitialWeight = @cWeight--CAST(@cWeight AS FLOAT) 
      WHERE	ID	= @cID			

      IF	@@ERROR <> 0
      BEGIN
         SET @nErrNo	= 145556
         SET @cErrMsg =	rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdateIDFail'
         GOTO Quit
      END
		
      --	EventLog	 
      EXEC RDT.rdt_STD_EventLog	
         @cActionType =	'3', -- logOut	 
         @cUserID		 =	@cUserName,	 
         @nMobileNo	 =	@nMobile,  
         @nFunctionID =	@nFunc,
         @cFacility	 =	@cFacility,	
         @cStorerKey	 =	@cStorerKey,
         @fWeight		 =	@cWeight,
         @cID			 =	@cID
		
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- QTY
      SET @cOutField03 = '' -- WEIGHT

      --	Go	to	prev screen
      SET @nScn  = @nScn -	1
      SET @nStep = @nStep - 1
		
   END   
	
   IF	@nInputKey = 0	--	ESC
   BEGIN	 
	
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- QTY
      SET @cOutField03 = '' -- WEIGHT

      --	Go	to	prev screen
      SET @nScn  = @nScn -	1
      SET @nStep = @nStep - 1

   END
	
   GOTO Quit
 
END
GOTO Quit

/********************************************************************************
Quit.	Update back	to	I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
   BEGIN
      UPDATE rdt.RDTMOBREC	WITH (ROWLOCK)	SET
      EditDate	= GETDATE(),  --(cc01)
      ErrMsg =	@cErrMsg,
      Func	 =	@nFunc,
      Step	 =	@nStep,
      Scn	 =	@nScn,

      StorerKey	 =	@cStorerKey,
      Facility		 =	@cFacility,
      --UserName		= @cUserName, --(cc01)
      Printer		 =	@cPrinter,	  
      V_QTY			 =	@cQTY,
      V_ID			 =	@cID,

      V_String1	 =	@cWeight, 
      V_String3	 =	@nFocusField, 

      I_Field01 =	@cInField01,  O_Field01	= @cOutField01,
      I_Field02 =	@cInField02,  O_Field02	= @cOutField02,
      I_Field03 =	@cInField03,  O_Field03	= @cOutField03,
      I_Field04 =	@cInField04,  O_Field04	= @cOutField04,
      I_Field05 =	@cInField05,  O_Field05	= @cOutField05,
      I_Field06 =	@cInField06,  O_Field06	= @cOutField06,
      I_Field07 =	@cInField07,  O_Field07	= @cOutField07,
      I_Field08 =	@cInField08,  O_Field08	= @cOutField08,
      I_Field09 =	@cInField09,  O_Field09	= @cOutField09,
      I_Field10 =	@cInField10,  O_Field10	= @cOutField10,
      I_Field11 =	@cInField11,  O_Field11	= @cOutField11,
      I_Field12 =	@cInField12,  O_Field12	= @cOutField12,
      I_Field13 =	@cInField13,  O_Field13	= @cOutField13,
      I_Field14 =	@cInField14,  O_Field14	= @cOutField14,
      I_Field15 =	@cInField15,  O_Field15	= @cOutField15
      WHERE	Mobile =	@nMobile
   END

GO
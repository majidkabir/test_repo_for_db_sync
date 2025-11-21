SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_PrepareNextScreen                       */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/*                                                                      */
/*                                                                      */
/************************************************************************/

CREATE PROC [rdt].[isp_PrepareNextScreen] (
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nInputKey       INT,           
   @cFacility       NVARCHAR( 5),  
   @cStorerKey      NVARCHAR( 15), 
   @cOption         NVARCHAR( 1),  
   @cConditionCode  NVARCHAR( 10),  
   @cValues         NVARCHAR( 1000),  --'01=a/*/02=b/*/03=2/*/'  => @cOutField01=a    @cOutField02=b    @cOutField03=2  
   @cOutField01     NVARCHAR( 60) OUTPUT, 
   @cOutField02     NVARCHAR( 60) OUTPUT,
   @cOutField03     NVARCHAR( 60) OUTPUT,
   @cOutField04     NVARCHAR( 60) OUTPUT,
   @cOutField05     NVARCHAR( 60) OUTPUT,
   @cOutField06     NVARCHAR( 60) OUTPUT, 
   @cOutField07     NVARCHAR( 60) OUTPUT, 
   @cOutField08     NVARCHAR( 60) OUTPUT,
   @cOutField09     NVARCHAR( 60) OUTPUT, 
   @cOutField10     NVARCHAR( 60) OUTPUT, 
   @cOutField11     NVARCHAR( 60) OUTPUT, 
   @cOutField12     NVARCHAR( 60) OUTPUT,
   @cOutField13     NVARCHAR( 60) OUTPUT, 
   @cOutField14     NVARCHAR( 60) OUTPUT, 
   @cOutField15     NVARCHAR( 60) OUTPUT, 
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT,
   @nNextScn        INT           OUTPUT,
   @nNextStep       INT           OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nIndex             INT = -1,
	  @nFieldIndex        INT = -1,
      @cConstantString    NVARCHAR(5) = '/*/',
	  @cConstantStringEqual    NVARCHAR(5) = '=',
	  @cFieldName         NVARCHAR(2),
	  @cFiledValue        NVARCHAR(100),
	  @cValuesCopy        NVARCHAR( 1000) = @cValues,
	  @nRowCount          INT;

   SET @nNextScn = 0;
   SET @nNextStep = 0;

   update RDT.RDTUser set OPSPosition = 'AAA' + @cStorerKey + CAST(@nStep AS NVARCHAR(5)) + @cConditionCode   WHERE UserName = 'NLT013' 
   SELECT 
      @nNextScn = NextScreen,
	  @nNextStep = NextStep
   FROM [RDT].[rdtScreenExtension] WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
       AND CurrentStep = @nStep
	   AND ConditionCode = @cConditionCode
	   AND Func = @nFunc;

   SELECT @nRowCount = @@ROWCOUNT;
   IF @nRowCount = 0
       GOTO Quit;

    SET @cOutField01 = '';
	SET @cOutField02 = '';
	SET @cOutField03 = '';
	SET @cOutField04 = '';
	SET @cOutField05 = '';
	SET @cOutField06 = '';
	SET @cOutField07 = '';
	SET @cOutField08 = '';
	SET @cOutField09 = '';
	SET @cOutField10 = '';
	SET @cOutField11 = '';
	SET @cOutField12 = '';
	SET @cOutField13 = '';
	SET @cOutField14 = '';
	SET @cOutField15 = '';
   
   --update RDT.RDTUser set OPSPosition = 'AAA-1' WHERE UserName = 'NLT013' 
  --update RDT.RDTUser set OPSPosition = ISNULL(@nNextScn, 'null scn') + '-' +  CAST(ISNULL( @nNextStep, 0) AS NVARCHAR(10)) WHERE UserName = 'NLT013' 

   WHILE (1=1)
   BEGIN
      SELECT @nFieldIndex = CHARINDEX(@cConstantString, @cValuesCopy);
	  IF @nFieldIndex < 1
	      BREAK;
	  
	  SET @cFiledValue = SUBSTRING( @cValuesCopy, 1, @nFieldIndex - 1 );

	  SET @nIndex = -1;
	  SELECT @nIndex = CHARINDEX(@cConstantStringEqual, @cFiledValue);

	  IF @nIndex < 1
	      BREAK;

	  SELECT @cFieldName = SUBSTRING( @cFiledValue, 1, @nIndex ), @cFiledValue = SUBSTRING( @cFiledValue, @nIndex + 1, LEN(@cFiledValue) - @nIndex + 1 );

	  SELECT
	      @cOutField01 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField01) = 0 ) AND @cFieldName = '01', @cFiledValue, @cOutField01 ),
		  @cOutField02 = IIF( ( @cOutField02 IS NULL OR LEN(@cOutField02) = 0 ) AND @cFieldName = '02', @cFiledValue, @cOutField02 ),
		  @cOutField03 = IIF( ( @cOutField03 IS NULL OR LEN(@cOutField03) = 0 ) AND @cFieldName = '03', @cFiledValue, @cOutField03 ),
		  @cOutField04 = IIF( ( @cOutField04 IS NULL OR LEN(@cOutField04) = 0 ) AND @cFieldName = '04', @cFiledValue, @cOutField04 ),
		  @cOutField05 = IIF( ( @cOutField05 IS NULL OR LEN(@cOutField05) = 0 ) AND @cFieldName = '05', @cFiledValue, @cOutField05 ),
		  @cOutField06 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField06) = 0 ) AND @cFieldName = '06', @cFiledValue, @cOutField06 ),
		  @cOutField07 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField07) = 0 ) AND @cFieldName = '07', @cFiledValue, @cOutField07 ),
		  @cOutField08 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField08) = 0 ) AND @cFieldName = '08', @cFiledValue, @cOutField08 ),
		  @cOutField09 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField09) = 0 ) AND @cFieldName = '09', @cFiledValue, @cOutField09 ),
		  @cOutField10 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField10) = 0 ) AND @cFieldName = '10', @cFiledValue, @cOutField10 ),
		  @cOutField11 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField11) = 0 ) AND @cFieldName = '11', @cFiledValue, @cOutField11 ),
		  @cOutField12 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField12) = 0 ) AND @cFieldName = '12', @cFiledValue, @cOutField12 ),
		  @cOutField13 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField13) = 0 ) AND @cFieldName = '13', @cFiledValue, @cOutField13 ),
		  @cOutField14 = IIF( ( @cOutField01 IS NULL OR LEN(@cOutField14) = 0 ) AND @cFieldName = '14', @cFiledValue, @cOutField14 ),
		  @cOutField15 = IIF( ( @cOutField15 IS NULL OR LEN(@cOutField15) = 0 ) AND @cFieldName = '15', @cFiledValue, @cOutField15 );

		SELECT @cValuesCopy = SUBSTRING(@cValuesCopy, @nFieldIndex + LEN(@cConstantString), LEN(@cValuesCopy) - @nFieldIndex + 1 );
   END;
   

Quit:
END; 

SET QUOTED_IDENTIFIER OFF 

GO
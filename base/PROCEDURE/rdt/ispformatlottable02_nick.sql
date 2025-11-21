SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [RDT].[ispFormatLottable02_Nick]            
	@nMobile          INT,         
	@nFunc            INT,          
	@cLangCode        NVARCHAR( 3),  
	@nInputKey        INT,           
	@cStorerKey       NVARCHAR( 15),
	@cSKU             NVARCHAR( 20), 
	@cLottableCode    NVARCHAR( 30), 
	@nLottableNo      INT,           
	@cFormatSP        NVARCHAR( 50), 
	@cLottableValue   NVARCHAR( 60), 
	@cLottable        NVARCHAR( 60) OUTPUT,
	@nErrNo           INT           OUTPUT, 
	@cErrMsg          NVARCHAR( 20) OUTPUT  

AS
BEGIN
    IF @nFunc = 600 AND @cStorerKey = 'NKST' AND @nLottableNo = 2 AND @cLottableValue IS NOT NULL AND @cLottableValue <> ''
	BEGIN
		SET @cLottable = 'NICK_' + @cLottableValue;
	END
	ELSE 
		SET @cLottable = 'NONE_' + @cLottableValue;

	SET @nErrNo = 0;
	SET @cErrMsg = '';
END
GO
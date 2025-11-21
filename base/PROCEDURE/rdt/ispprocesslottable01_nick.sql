SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [RDT].[ispProcessLottable01_Nick]            
	@nMobile          INT,     
	@nFunc            INT,          
	@cLangCode        NVARCHAR( 3),  
	@nInputKey        INT,           
	@cStorerKey       NVARCHAR( 15), 
	@cSKU             NVARCHAR( 20), 
	@cLottableCode    NVARCHAR( 30),
	@nLottableNo      INT,           
	@cLottable        NVARCHAR( 30), 
	@cType            NVARCHAR( 10),  
	@cSourceKey       NVARCHAR( 15), 
	@cLottable01Value NVARCHAR( 18), 
	@cLottable02Value NVARCHAR( 18), 
	@cLottable03Value NVARCHAR( 18), 
	@dLottable04Value DATETIME,     
	@dLottable05Value DATETIME,      
	@cLottable06Value NVARCHAR( 30), 
	@cLottable07Value NVARCHAR( 30), 
	@cLottable08Value NVARCHAR( 30),
	@cLottable09Value NVARCHAR( 30), 
	@cLottable10Value NVARCHAR( 30), 
	@cLottable11Value NVARCHAR( 30), 
	@cLottable12Value NVARCHAR( 30),
	@dLottable13Value DATETIME,      
	@dLottable14Value DATETIME,     
	@dLottable15Value DATETIME,      
	@cLottable01      NVARCHAR( 18) OUTPUT, 
	@cLottable02      NVARCHAR( 18) OUTPUT, 
	@cLottable03      NVARCHAR( 18) OUTPUT, 
	@dLottable04      DATETIME      OUTPUT, 
	@dLottable05      DATETIME      OUTPUT, 
	@cLottable06      NVARCHAR( 30) OUTPUT, 
	@cLottable07      NVARCHAR( 30) OUTPUT, 
	@cLottable08      NVARCHAR( 30) OUTPUT, 
	@cLottable09      NVARCHAR( 30) OUTPUT, 
	@cLottable10      NVARCHAR( 30) OUTPUT, 
	@cLottable11      NVARCHAR( 30) OUTPUT, 
	@cLottable12      NVARCHAR( 30) OUTPUT, 
	@dLottable13      DATETIME      OUTPUT, 
	@dLottable14      DATETIME      OUTPUT, 
	@dLottable15      DATETIME      OUTPUT, 
	@nErrNo           INT           OUTPUT, 
	@cErrMsg          NVARCHAR( 20) OUTPUT  

AS
BEGIN
    IF @nFunc = 600 AND @cStorerKey = 'NKST' AND @nLottableNo = 2 AND @cLottableCode = 'STD' AND @cLottable01Value IS NOT NULL AND @cLottable01Value <> ''
	BEGIN
		SET @cLottable = 'CL_' + @cLottable01Value;
	END
	ELSE 
		SET @cLottable = 'NONE_' + @cLottable01Value;

	SET @nErrNo = 0;
	SET @cErrMsg = '';
END
GO
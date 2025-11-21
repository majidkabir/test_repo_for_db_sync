SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   PROCEDURE [RDT].[rdtConvertToDate_NICK0] (
   @cDate DATETIME,
   @cOutputDate DATETIME OUTPUT
) 
AS
BEGIN
	

	DECLARE @tReturnData SPReturnDataTable

	print '1'
	SET @cOutputDate = DATEADD( DD, 2, @cDate)

	INSERT INTO @tReturnData ( Variable, Value )
	VALUES( '@cID', 'LP2401'),
	( '@cSKU', 'NNFG008')

	SELECT * FROM @tReturnData
END

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE dbo.lspLogiReportTestNick   
    @in_vchStorerKey nvarchar(50)
AS   

    SET NOCOUNT ON;  
    
	SELECT TOP 10 
		Lot, Loc, Id, StorerKey, StorerKey, Sku, Qty, 
		QtyAllocated, QtyExpected, QtyPickInProcess,QtyReplen 
	FROM LOTXLOCXID WITH(NOLOCK)
	WHERE StorerKey = @in_vchStorerKey;

GO
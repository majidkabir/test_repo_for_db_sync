SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[v_ReceiptSerialno]
as
SELECT *
FROM dbo.ReceiptSerialno (NOLOCK)

GO
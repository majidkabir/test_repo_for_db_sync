SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_LoadPlanRetDetail]
AS
SELECT     LoadKey, LoadLineNumber, ReceiptKey, ExternReceiptKey, AddWho, AddDate, EditWho, EditDate, TrafficCop, ArchiveCop, Weight, Cube,
                      ExternLoadKey, ExternLineNo
FROM         dbo.LoadPlanRetDetail WITH (NOLOCK)


GO
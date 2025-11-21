SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_PackInfo_Test]
AS
SELECT PickSlipNo
,CartonNo
,[Weight]
,[Cube]
,Qty
,AddDate
,AddWho
,EditDate
,EditWho
,CartonType
,RefNo
,[Length]
,Width
,Height
,[ItemCube] = [Cube]
FROM [dbo].[PackInfo] (NOLOCK)

GO
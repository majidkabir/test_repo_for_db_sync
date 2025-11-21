SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_DropID_EventLog]
AS
SELECT d.DropId,
       d.DropLoc,
       CASE RE.EventType
            WHEN '1' THEN 'Receiving'
            WHEN '2' THEN 'Return'
            WHEN '3' THEN 'Picking'
            WHEN '4' THEN 'Move'
            WHEN '5' THEN 'Replenishment'
            WHEN '6' THEN 'XDOCK'
            WHEN '7' THEN 'Putaway'
            WHEN '8' THEN 'Cycle Count'
            WHEN '9' THEN 'Activity Tracking'
            ELSE ''
            END AS 'EventType',
       RE.Location,
       RE.ToLocation,
       RE.EventDateTime,
       C.[Description] AS ActionType,
       RE.UserID,
       RE.RefNo1 AS Loadkey
  FROM Dropid d WITH (NOLOCK)
JOIN Rdt.rdtStdEventLog RE WITH (NOLOCK) ON d.Dropid = RE.ToID
LEFT OUTER JOIN CODELKUP c WITH (NOLOCK) ON c.ListName = 'RDTACTTYPE' AND C.Code = RE.ActionType




GO
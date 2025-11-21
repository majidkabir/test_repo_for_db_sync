SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_LoadPlanLaneDetail]  
AS  
SELECT     LoadKey, ExternOrderKey, ConsigneeKey, LP_LaneNumber, LocationCategory, LOC, Status, Notes, AddWho, AddDate, EditWho, EditDate, TrafficCop,   
                      ArchiveCop, MBOLKey  
FROM         dbo.LoadPlanLaneDetail WITH (nolock)  
  
GO
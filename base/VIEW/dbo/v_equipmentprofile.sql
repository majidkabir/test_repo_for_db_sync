SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_EquipmentProfile]  AS  SELECT [EquipmentProfileKey] , [Descr] , [MaximumWeight] , [WeightReductionPerLevel] , [AddDate] , [AddWho] , [EditDate] , [EditWho] , [TrafficCop] , [ArchiveCop] 
,MaximumLevel
,MaximumHeight
FROM [EquipmentProfile] (NOLOCK)  


GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
   CREATE VIEW dbo.V_SKUConfig AS    
   SELECT [StorerKey]  
      ,[SKU]  
      ,[ConfigType]  
      ,[Data]  
      ,[Addwho]  
      ,[AddDate]  
      ,[EditWho]  
      ,[EditDate]  
      ,[userdefine01]  
      ,[userdefine02]  
      ,[userdefine03]  
      ,[userdefine04]  
      ,[userdefine05]  
      ,[userdefine06]  
      ,[userdefine07]  
      ,[userdefine08]  
      ,[userdefine09]  
      ,[userdefine10]  
      ,[userdefine11]  
      ,[userdefine12]  
      ,[userdefine13]  
      ,[userdefine14]  
      ,[userdefine15]  
      ,[notes]  
   FROM dbo.SKUConfig (nolock)  

GO
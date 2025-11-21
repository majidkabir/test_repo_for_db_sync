SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE VIEW [dbo].[PackView] AS    
 SELECT PackKey, PackDescr, UOM, Min(UOMVal) AS UOMValue    
 FROM (    
  SELECT PackKey, PackDescr, PackUOM1 AS UOM, CaseCnt AS UOMVal FROM [DBO].PACK with (NOLOCK)  
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM2, InnerPack FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM3, Qty FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM4, Pallet FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM5, Cube FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM6, Grosswgt FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM7, NetWgt FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL    
  SELECT PackKey, PackDescr, PackUOM8, OtherUnit1 FROM [DBO].PACK  with (NOLOCK)   
 UNION ALL   
  SELECT PackKey, PackDescr, PackUOM9, OtherUnit2 FROM [DBO].PACK  with (NOLOCK) ) AS P    
 GROUP BY PackKey, PackDescr, UOM    

GO
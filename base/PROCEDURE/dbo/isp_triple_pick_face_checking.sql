SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/****************************************************************************************/        
/* Store Procedure: isp_Triple_Pick_Face_Checking                                       */        
/* Creation Date:                                                                       */        
/* Copyright: IDS                                                                       */        
/* Written by: Jay Chua                                                                 */        
/*                                                                                      */        
/* Purpose: For Hyperion Job - Triple Pick Face Checking                                */        
/*                                                                                      */        
/* Called By: Hyperion                                                                  */        
/*                                                                                      */        
/* PVCS Version: 1.0                                                                    */        
/*                                                                                      */        
/* Version: 1.0                                                                         */        
/*                                                                                      */        
/* Data Modifications:                                                                  */        
/*                                                                                      */        
/* Updates:                                                                             */        
/* Date         Author  Ver.  Purposes                                                  */        
/* 04-05-2019   JayChua  1.0   Triple Pick Face Checking                                */        
/****************************************************************************************/        
     
CREATE PROC [dbo].[isp_Triple_Pick_Face_Checking]        
    
AS      
    
BEGIN     
    
SELECT l.Putawayzone                    AS 'Putaway Zone',   
       l.Loc                            AS 'Location',   
       sl.Locationtype                   AS 'Type',   
       sl.Sku,   
       s.Skugroup                       AS 'SKU Group',   
       Isnull(SL.Qtylocationminimum, 0) AS 'Min Capacity',   
       Isnull(SL.Qtylocationlimit, 0)   AS 'Max Capacity',   
       Isnull(SL.Qty, 0)                AS  Qty,   
       Count(DISTINCT sl.Sku)           AS 'SKU Count',   
       l.Locaisle                       AS 'Location Aisle'   
  
    into #TEMPTABLE  
FROM   loc l (nolock)   
    LEFT JOIN skuxloc sl(nolock)   
    ON ( sl.Loc = l.Loc )   
       LEFT JOIN sku s (nolock)   
       ON ( s.Sku = sl.Sku )   
WHERE   (sl.Storerkey = 'triple' or sl.StorerKey is null)  
  AND l.PutawayZone in ('BH01','BH02','BH03','BH04','BH05','BH06','BH07','BH08','BH09','BH10')  
GROUP  BY l.Putawayzone,   
          l.Loc,   
          sl.Locationtype,   
          sl.Sku,   
          s.Skugroup,   
          SL.Qtylocationminimum,   
          sl.Qtylocationlimit,   
          sl.Qty,   
          l.Locaisle   
ORDER  BY 1,   
          2,   
          3,   
          4,   
          5           
    
    
SELECT * FROM #TEMPTABLE    
    
DROP TABLE #TEMPTABLE    
    
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: V_PP_MOVETASK                                      */  
/* Creation Date: 15-Sep-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:  SOS#224300- PP Move Task                                   */  
/*                                                                      */ 
/* Called By:                                                           */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/ 

CREATE VIEW V_PP_MOVETASK
AS 
SELECT Storerkey
      ,Sku
      ,Lot
      ,FromLoc
      ,FromID 
      ,SUM(Qty) Qty
FROM dbo.TaskDetail WITH (NOLOCK) 
WHERE TaskType = 'MV' 
AND PickMethod = 'PP' 
AND Status NOT IN ('S','9','X')
GROUP BY Storerkey
      ,  Sku
      ,  Lot
      ,  FromLoc
      ,  FromID 


GO
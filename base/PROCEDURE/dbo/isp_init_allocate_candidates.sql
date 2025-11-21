SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Init_Allocate_Candidates                       */    
/* Creation Date: 2020-04-08                                            */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Dynamic SQL review, impact SQL cache log                    */
/*                                                                      */    
/* Called By: Insert #temp Table PickCode                               */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */    
/************************************************************************/ 
CREATE PROC [dbo].[isp_Init_Allocate_Candidates]  
AS  
BEGIN 
   SET NOCOUNT ON 

   TRUNCATE TABLE #ALLOCATE_CANDIDATES       

END

GO
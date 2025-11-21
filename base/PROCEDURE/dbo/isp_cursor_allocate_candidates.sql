SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Cursor_Allocate_Candidates                     */    
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
CREATE PROC [dbo].[isp_Cursor_Allocate_Candidates] 
   @n_SkipPreAllocationFlag INT  = 1   --1: Return Lot Column, 0:Do not return Lot Column
AS  
BEGIN 
   SET NOCOUNT ON 

   IF @n_SkipPreAllocationFlag = 1
   BEGIN
      DECLARE CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY       
      FOR      
         SELECT Lot   
               ,Loc   
               ,ID     
               ,QtyAvailable  
               ,OtherValue  
         FROM  #ALLOCATE_CANDIDATES     
         ORDER BY RowID 
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY       
      FOR      
         SELECT Loc   
               ,ID     
               ,QtyAvailable  
               ,OtherValue  
         FROM  #ALLOCATE_CANDIDATES     
         ORDER BY RowID 
   END       
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGetOverPickLoc03                                */  
/* Creation Date: 20-MAR-2023                                           */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-22050 TH-DSG Mutiple pick loc by lottable03 refer to    */     
/*          Codelkup.                                                   */
/*                                                                      */  
/* Called By: Over Allocation                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/* 20-Mar-2023  NJOW     1.0  DEVOPS Combine Script                     */
/************************************************************************/  
  
CREATE   PROC [dbo].[ispGetOverPickLoc03]     
   @c_Storerkey NVARCHAR(15),   
   @c_Sku NVARCHAR(20),   
   @c_AllocateStrategykey NVARCHAR(10),  
   @c_AllocateStrategyLineNumber NVARCHAR(5),  
   @c_LocationTypeOverride NVARCHAR(10),   
   @c_LocationTypeOverridestripe NVARCHAR(10),  
   @c_Facility NVARCHAR(5),   
   @c_HostWHCode NVARCHAR(10),   
   @c_Orderkey NVARCHAR(10),   
   @c_Loadkey NVARCHAR(10),   
   @c_Wavekey NVARCHAR(10),   
   @c_Lot NVARCHAR(10),   
   @c_Loc NVARCHAR(10),   
   @c_ID NVARCHAR(18),   
   @c_UOM NVARCHAR(10), --allocation strategy UOM  
   @n_QtyToTake INT,   
   @n_QtyLeftToFulfill INT,   
   @c_CallSource NVARCHAR(20), ----ORDER, LOADORDER, LOADCONSO, WAVEORDER, WAVECONSO  
   @b_success INT OUTPUT,   
   @n_err INT OUTPUT,   
   @c_ErrMsg NVARCHAR(250) OUTPUT  
AS     
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @n_Continue            INT,  
           @n_StartTCnt           INT,  
           @c_Lottable03          NVARCHAR(18),
           @c_Floor               NVARCHAR(3)
                        
  SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1  
  
  CREATE TABLE #PICKLOCTYPE (loc  NVARCHAR(10) )  
  
  IF @n_continue IN (1,2)  
  BEGIN    	  	  	
  	 SELECT @c_Lottable03 = LA.Lottable03
  	 FROM LOTATTRIBUTE LA (NOLOCK)
  	 WHERE LA.Lot = @c_Lot
  	 
  	 SELECT @c_Floor = LOC.[Floor]
  	 FROM CODELKUP CL (NOLOCK)  	 
     JOIN LOC (NOLOCK) ON CL.Code2 = LOC.[Floor]
  	 WHERE CL.ListName = 'DSGLOC'
  	 AND CL.Code = @c_Lottable03
  	
  	 INSERT INTO #PICKLOCTYPE
  	    SELECT TOP 1 SKUXLOC.LOC    
        FROM SKUxLOC (NOLOCK)   
        JOIN LOC (NOLOCK) ON SKUXLOC.loc = LOC.loc
        WHERE SKUxLOC.STORERKEY = @c_StorerKey    
        AND SKUxLOC.SKU = @c_Sku    
        AND SKUxLOC.LocationType = @c_LocationTypeOverride      
        AND LOC.facility = @c_Facility           
        AND LOC.[Floor] = @c_Floor
        ORDER BY LOC.LogicalLocation, LOC.Loc                 
  END  
  
  SELECT Loc FROM #PICKLOCTYPE
     
QUIT_SP:  
     
  IF @n_Continue=3  -- Error Occured - Process AND Return  
  BEGIN  
     SELECT @b_Success = 0  
     IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
     BEGIN  
      ROLLBACK TRAN  
     END  
     ELSE  
     BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
       COMMIT TRAN  
      END  
     END  
     EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispGetOverPickLoc03'    
     --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
     RETURN  
  END  
  ELSE  
  BEGIN  
     SELECT @b_Success = 1  
     WHILE @@TRANCOUNT > @n_StartTCnt  
     BEGIN  
      COMMIT TRAN  
     END  
     RETURN  
  END    
END    

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_013_PreGenRptData            */        
/* Creation Date: 29-AUG-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: Convert to Logi Report - r_dw_print_wave_pickslip (TW)      */      
/*                                                                      */        
/* Called By: RPT_WV_PLIST_WAVE_013__PreGenRptData								*/        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 24-AUG-2022  WZPang   1.0  DevOps Combine Script                     */     
/************************************************************************/        
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_013_PreGenRptData] (
      @c_WaveKey           NVARCHAR(10)
    , @c_PreGenRptData     NVARCHAR(10)
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON   
   
   DECLARE  @n_continue       INT,
            @c_errmsg         NVARCHAR(255),
            @b_success        INT,
            @n_err            INT,
            @n_starttcnt      INT

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

   EXEC isp_RPT_WV_PLIST_WAVE_013_1 @c_WaveKey, @c_PreGenRptData

   EXEC isp_RPT_WV_PLIST_WAVE_013_3 @c_WaveKey, @c_PreGenRptData


END -- procedure    

GO
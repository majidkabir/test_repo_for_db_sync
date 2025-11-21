SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_stocktake_control_log_02                            */  
/* Creation Date: 17-NOV-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-18375 - PH UNILEVER CONTROL LOG REPORT CR               */   
/*        :                                                             */  
/* Called By: r_dw_stocktake_control_log_02                             */
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 17-NOV-2021  CSCHONG   1.0 Devops Scripts Combine                    */
/************************************************************************/ 

CREATE PROC [dbo].[isp_stocktake_control_log_02]  
            @c_cckey   NVARCHAR(10)  
       
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
        SELECT  LOC.Facility,
                StorerKey = CASE WHEN ((STOCKTAKESHEETPARAMETERS.Storerkey like '%-%') OR  
                                       (STOCKTAKESHEETPARAMETERS.Storerkey like '%,%')) 
                                 THEN ''
                                 ELSE MAX(STORER.Storerkey) END,
                Company = CASE WHEN ((STOCKTAKESHEETPARAMETERS.Storerkey like '%-%') OR  
                                     (STOCKTAKESHEETPARAMETERS.Storerkey like '%,%')) 
                               THEN ''
                               ELSE MAX(STORER.Company) END,
                CCDETAIL.CCKey,
                CCDETAIL.CCSheetNo,
                MIN(CCDETAIL.LOC) as Location_From,
                MAX(CCDETAIL.LOC) as Location_To,
                LOC.LOCAISLE, 
                LOC.LOCLEVEL 
         FROM CCDETAIL WITH (NOLOCK)
         LEFT OUTER JOIN LOC WITH (NOLOCK) ON (CCDETAIL.Loc = LOC.Loc)
         LEFT OUTER JOIN STORER WITH (NOLOCK) ON (CCDETAIL.Storerkey = STORER.Storerkey)
         LEFT OUTER JOIN STOCKTAKESHEETPARAMETERS WITH (NOLOCK) ON (CCDETAIL.CCkey = STOCKTAKESHEETPARAMETERS.Stocktakekey)
         WHERE (CCDETAIL.CCKey = @c_cckey)
         GROUP BY LOC.Facility,
                  CCDETAIL.CCKey,
                  CCDETAIL.CCSheetNo,
                  STOCKTAKESHEETPARAMETERS.Storerkey,  
                  LOC.LOCAISLE, 
                  LOC.LOCLEVEL 
         ORDER BY CCDETAIL.CCSheetNo 
  
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_stocktake_control_log_02'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
    
   WHILE @@TRANCOUNT < @n_StartTCnt   
      BEGIN TRAN;     
  
END

GO